# APP.PY

## Quick TL;DR  

| Concept | What it means in the snippet | Why it matters |
|---------|-----------------------------|----------------|
| **`os.getenv`** | Reads an environment variable (`SALAD_MACHINE_ID`) and falls back to `"localhost"` if it isn’t set. | Lets you inject configuration without changing code (e.g. different IDs in dev vs prod). |
| **FastAPI** | A modern, async‑first web framework. `FastAPI()` creates the “application object” that will receive HTTP requests. | Gives you a clean way to declare routes (`@app.get(...)`) and automatically generates OpenAPI docs. |
| **`@app.get("/path")`** | Decorator that registers an **endpoint** (a URL that can be called) for HTTP GET requests. | The function underneath becomes the handler for that URL. |
| **`async def`** | Declares an **asynchronous** coroutine. FastAPI can run it without blocking the event loop. | Enables high‑concurrency (many requests at once) with very little overhead. |
| **Probes (`/started`, `/ready`, `/live`)** | Simple health‑check endpoints that return a tiny JSON payload. | Used by orchestration tools like Kubernetes to know if the service is up, ready to accept traffic, or still alive. |
| **“entrypoint”** (in the Python/packaging sense) | Not shown in the code itself, but the *thing that runs the app* – e.g. `uvicorn mymodule:app` or a `console_scripts` entry point in `setup.cfg`. | It’s the command the OS/container executes to start the web server. |

Below is a **step‑by‑step walkthrough** of the file you posted, followed by a short primer on the different kinds of “entrypoints” you’ll encounter, and finally a **hands‑on guide** to get this service running locally, in Docker, and in a Kubernetes‑style environment.

---

## 1️⃣ Line‑by‑line walk‑through

```python
from fastapi import FastAPI          # 1
import os                            # 2
```

* **Line 1** imports the `FastAPI` class. Creating an instance of this class gives you a *WSGI/ASGI* application object that can be served by an ASGI server (e.g. `uvicorn` or `hypercorn`).
* **Line 2** imports the standard‑library `os` module, which gives access to environment variables, file paths, etc.

```python
salad_machine_id = os.getenv("SALAD_MACHINE_ID", "localhost")   # 3
```

* `os.getenv(key, default)` asks the OS for the value of the environment variable `SALAD_MACHINE_ID`.  
* If the variable is **not** defined, `"localhost"` is used instead.  
* The result is stored in the module‑level variable `salad_machine_id`, so every request handler can read it without doing extra work.

```python
app = FastAPI()                     # 4
```

* This creates the **FastAPI application object**. Think of it as the “brain” that knows:
  * Which URL routes exist (`/hello`, `/started`, …)
  * Which Python functions handle those routes
  * How to serialize/deserialize JSON, validate data, generate OpenAPI docs, etc.

```python
@app.get("/hello")                  # 5
async def hello_world():            # 6
    return {"message": "Hello, World!", "salad_machine_id": salad_machine_id}
```

* **Line 5** – The `@app.get("/hello")` decorator tells FastAPI: “When an HTTP **GET** request comes in for the path `/hello`, run the function that follows.”
* **Line 6** – Declares an **asynchronous** function (`async def`). FastAPI will `await` it automatically.  
* The function returns a plain Python `dict`. FastAPI (via Starlette) automatically turns that into a JSON response with `Content-Type: application/json`.

The next three groups of lines are essentially the same pattern, just exposing different health‑check URLs:

```python
@app.get("/started")
async def startup_probe():
    return {"message": "Started!"}
```

```python
@app.get("/ready")
async def readiness_probe():
    return {"message": "Ready!"}
```

```python
@app.get("/live")
async def liveness_probe():
    return {"message": "Live!"}
```

* **Why three probes?**  
  * **`/started`** – “I have started the process.” Often used right after the container/process boots.  
  * **`/ready`** – “All dependencies (DB, external APIs, caches…) are healthy; you can start sending real traffic.”  
  * **`/live`** – “I’m still alive; don’t kill me.” Usually a very cheap check that just returns 200.

These are the exact names Kubernetes expects when you configure **liveness** and **readiness** probes, but they work anywhere else too (e.g., load‑balancers, monitoring scripts).

---

## 2️⃣ What is an **entrypoint**? (Two common meanings)

| Context | What the term refers to | Typical syntax / file |
|---------|------------------------|----------------------|
| **Python packaging** (e.g., `setup.cfg` / `pyproject.toml`) | A *console script* that the installer creates in the user's `$PATH`. When you run `my‑tool` on the command line, Python actually executes `module_name:function_name`. | ```toml<br>[project.scripts] <br>salad‑service = "my_pkg.main:app"``` |
| **Docker / OS** | The command that the container (or a Unix process) runs when it starts. In a Dockerfile it’s the `ENTRYPOINT` (or `CMD`). | ```Dockerfile<br>ENTRYPOINT ["uvicorn", "my_pkg:app", "--host", "0.0.0.0", "--port", "8000"]``` |

In the **code you posted**, the entrypoint isn’t defined yet – you still need *something* that launches the ASGI server and points it at the `app` object you just created. That “something” is the entrypoint.

### 2.1 Example: `uvicorn` as the entrypoint

```bash
uvicorn mymodule:app --host 0.0.0.0 --port 8000
```

* `mymodule` is the **Python file name without the `.py` extension** (e.g., `main.py` → `main`).
* `app` is the variable we defined (`app = FastAPI()`).

You can also expose this via a *console script* entry point:

```toml
# pyproject.toml
[project]
name = "salad-service"
version = "0.1.0"
dependencies = ["fastapi", "uvicorn"]

[project.scripts]
salad-service = "salad_service.main:run"
```

```python
# salad_service/main.py
from fastapi import FastAPI
import os
import uvicorn

app = FastAPI()
# … (the route definitions from above) …

def run():
    """Entry point used by `python -m salad_service` or the console script."""
    uvicorn.run("salad_service.main:app", host="0.0.0.0", port=8000, reload=True)
```

Now a user can simply type:

```bash
salad-service           # the console script created by the installer
# or
python -m salad_service # same thing, no installer needed
```

Both commands will start the same ASGI server.

---

## 3️⃣ How to **run** this code right now (no Docker, just your laptop)

1. **Create a virtual environment** (optional but recommended)

   ```bash
   python3 -m venv .venv
   source .venv/bin/activate   # on Windows: .venv\Scripts\activate
   ```

2. **Install the dependencies**

   ```bash
   pip install fastapi uvicorn
   ```

3. **Save the snippet** to a file, e.g. `main.py`

4. **Start the server**

   ```bash
   uvicorn main:app --reload
   ```

   * `--reload` makes the server watch the source files and restart automatically – perfect for development.

5. **Test it**

   Open a browser or use `curl`:

   ```bash
   curl http://127.0.0.1:8000/hello
   # → {"message":"Hello, World!","salad_machine_id":"localhost"}

   curl http://127.0.0.1:8000/ready
   # → {"message":"Ready!"}
   ```

   FastAPI also automatically generates interactive docs:

   * **Swagger UI** → `http://127.0.0.1:8000/docs`
   * **ReDoc** → `http://127.0.0.1:8000/redoc`

   Those pages list every endpoint and let you call them from a web UI.

---

## 4️⃣ Packaging it into a **Docker image** (the most common way to ship a FastAPI service)

### 4.1 Minimal `Dockerfile`

```dockerfile
# ---------- Stage 1: Build ----------
FROM python:3.12-slim AS builder

# Install a tiny compiler (only needed if you have compiled deps)
RUN apt-get update && apt-get install -y --no-install-recommends gcc && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy just the metadata first so Docker can cache the layer if dependencies don't change
COPY pyproject.toml poetry.lock* ./
# If you use pip+requirements.txt:
#   COPY requirements.txt .
#   RUN pip install --no-cache-dir -r requirements.txt

# Install dependencies (no source code yet)
RUN pip install --no-cache-dir fastapi uvicorn

# ---------- Stage 2: Runtime ----------
FROM python:3.12-slim

WORKDIR /app

# Copy the *installed* packages from builder (helps keep image small)
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy the application code
COPY main.py .

# The environment variable is optional; you can also pass it at `docker run`
ENV SALAD_MACHINE_ID=localhost

# Expose the port FastAPI runs on (default 8000)
EXPOSE 8000

# ENTRYPOINT tells Docker what to execute when the container starts
ENTRYPOINT ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### 4.2 Build & run

```bash
docker build -t salad-service .
docker run -p 8000:8000 -e SALAD_MACHINE_ID=my‑real‑id salad-service
```

Now `http://localhost:8000/hello` will return the ID you passed via `-e`.

---

## 5️⃣ Using the **health probes** with Kubernetes (or any orchestrator)

A minimal `deployment.yaml` snippet:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: salad-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: salad-service
  template:
    metadata:
      labels:
        app: salad-service
    spec:
      containers:
        - name: salad
          image: yourrepo/salad-service:latest
          ports:
            - containerPort: 8000
          env:
            - name: SALAD_MACHINE_ID
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name   # example: use pod name as the ID
          livenessProbe:
            httpGet:
              path: /live
              port: 8000
            initialDelaySeconds: 5
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /ready
              port: 8000
            initialDelaySeconds: 5
            periodSeconds: 5
          startupProbe:
            httpGet:
              path: /started
              port: 8000
            failureThreshold: 30   # try for up to 30×periodSeconds
            periodSeconds: 10
```

* **`livenessProbe`** → Kubernetes kills the pod if `/live` returns non‑2xx.
* **`readinessProbe`** → The pod is removed from service load‑balancing until `/ready` succeeds.
* **`startupProbe`** (optional, newer API) → Gives the container extra time to start before liveness checks start firing.

---

## 6️⃣ TL;DR Checklist

| ✅ What you need | How to do it |
|-----------------|--------------|
| **Python code** | Save the snippet as `main.py`. |
| **FastAPI + Uvicorn** | `pip install fastapi uvicorn`. |
| **Run locally** | `uvicorn main:app --reload`. |
| **Expose config** | Set `SALAD_MACHINE_ID` in the environment (`export SALAD_MACHINE_ID=foo`). |
| **Docker** | Use the Dockerfile above → `docker build -t salad . && docker run -p 8000:8000 salad`. |
| **K8s probes** | Add `/live`, `/ready`, `/started` endpoints and reference them in the pod spec. |
| **Entry point** | Either run `uvicorn …` directly, or create a console‑script (`salad-service = main:run`) that calls `uvicorn.run(...)`. |

---

## 7️⃣ Where to go from here

| Topic | Why it matters | Quick resources |
|-------|----------------|-----------------|
| **Async & concurrency** | FastAPI shines when you `await` I/O (DB, HTTP calls). Learn `async def`, `await`, and libraries like `httpx` or `databases`. | *“Async IO in Python”* – Real Python tutorial |
| **Dependency injection** | FastAPI lets you declare “dependencies” (DB session, auth) that are automatically injected into each route. | FastAPI docs: *Dependencies* |
| **Testing** | `TestClient` from `fastapi.testclient` makes it trivial to unit‑test your endpoints. | FastAPI testing guide |
| **Production server** | Uvicorn is fine for dev; for production you may wrap it with **Gunicorn** (`gunicorn -k uvicorn.workers.UvicornWorker`). | Gunicorn + Uvicorn docs |
| **OpenAPI / Docs** | The `/docs` and `/redoc` pages are auto‑generated. You can also add **Pydantic models** to validate request bodies. | FastAPI – *Path Parameters, Query Parameters, Body* |
| **CI/CD** | Build the Docker image in GitHub Actions / GitLab CI, push to a registry, let Kubernetes pull it. | GitHub Actions “Docker Build and Push” workflow template |

---

### 🎉 You’re ready!

You now understand:

* What each line of the snippet does.
* How environment variables (`os.getenv`) make the app configurable.
* How FastAPI registers routes with decorators.
* What the three health‑check endpoints are for.
* The two main meanings of *entrypoint* and how to actually start the app (via `uvicorn` or a console script).
* How to run it locally, containerize it, and hook it up to Kubernetes probes.

Happy coding, and may your **salad machines** never go stale! 🚀
