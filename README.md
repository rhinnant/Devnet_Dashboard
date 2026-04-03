# Devnet_Dashboard
how to setup my application 

requirements:
1.) make a username 
type:  useradd hinn
type:  passwd hinn 
password: 2wsx3edc@WSX#EDC

Note: This repository should be made inside "hinn" username


Step-by-Step Instructions to Setup and Run Your Django Project

Step 0 — Go to your home/project folder
cd ~

Step 1 — Create a folder for instructions/projects
mkdir project_instructions
cd project_instructions

Step 2 — Initialize Git (optional)
git init

Step 3 — Clone your GitHub repository
git clone git@github.com:rhinnant/Devnet_Dashboard.git
cd Devnet_Dashboard

Step 4 — Make sure Python3 is installed
python3 --version

Step 5 — Create a Python virtual environment
python3 -m venv venv

Step 6 — Activate the virtual environment
source venv/bin/activate
# Your prompt should now show (venv)

Step 7 — Upgrade pip (optional)
pip install --upgrade pip

Step 8 — Install Django and dependencies
pip install django
pip install -r requirements.txt

Step 9 — Apply Django migrations
python manage.py migrate

Step 10 — Run the development server
python manage.py runserver
# The server runs at http://127.0.0.1:8000/

Optional Tips:
1. Every time you open a new terminal, activate the venv:
   cd ~/project_instructions/Devnet_Dashboard
   source venv/bin/activate

2. Do not push venv/ to GitHub. Use requirements.txt instead.

3. If new apps are added, always run:
   python manage.py makemigrations
   python manage.py migrate



   ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


Instructions on containeriing you application with Docker 

Step-by-Step Docker Instructions for Devnet_Dashboard

Step 1 — Create a Dockerfile in the project root
------------------------------------------------
# Use official Python image
FROM python:3.12-slim

# Prevent Python from writing .pyc files and buffer output
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Set working directory
WORKDIR /app

# Copy dependencies first
COPY requirements.txt .

# Install Python dependencies
RUN pip install --upgrade pip
RUN pip install -r requirements.txt

# Copy the rest of the project
COPY . .

# Expose the port Django will run on
EXPOSE 8000

# Run migrations and start server
CMD ["sh", "-c", "python manage.py migrate && python manage.py runserver 0.0.0.0:8000"]

Step 2 — Create a .dockerignore file
------------------------------------
venv/
__pycache__/
*.pyc
*.pyo
*.pyd
*.sqlite3
*.log
*.env
*.DS_Store

Step 3 — Build the Docker image
-------------------------------
docker build -t devnet_dashboard .

Step 4 — Run the container
--------------------------
docker run -d -p 8000:8000 devnet_dashboard

# Check logs if needed
docker logs -f <container_id>

Step 5 — Access your Django app
--------------------------------
Open your browser and go to:
http://127.0.0.1:8000/

Tips:
-----
1. Rebuild the image whenever code changes:
   docker build -t devnet_dashboard .
   docker run -d -p 8000:8000 devnet_dashboard

2. No need for virtual environment on host — container handles Python and dependencies.
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Instruction on deloying container inside kubernetes


# Step 1: Go to your project
cd ~/project_intructions/Devnet_Dashboard

# Step 2: Point Docker to Minikube
eval $(minikube docker-env)

# Step 3: Build Docker image
docker build -t devnet_dashboard:latest .

# Step 4: Create deployment YAML (save as devnet-dashboard-deployment.yaml)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: devnet-dashboard
spec:
  replicas: 1
  selector:
    matchLabels:
      app: devnet-dashboard
  template:
    metadata:
      labels:
        app: devnet-dashboard
    spec:
      containers:
      - name: devnet-dashboard
        image: devnet_dashboard:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8000

# Step 5: Apply the deployment
kubectl apply -f devnet-dashboard-deployment.yaml

# Step 6: Create service YAML (save as devnet-dashboard-service.yaml)
apiVersion: v1
kind: Service
metadata:
  name: devnet-dashboard-service
spec:
  selector:
    app: devnet-dashboard
  type: NodePort
  ports:
    - port: 8000
      targetPort: 8000
      nodePort: 31766

# Step 7: Apply the service
kubectl apply -f devnet-dashboard-service.yaml

# Step 8: Check pods and service
kubectl get pods -w
kubectl get svc

# Step 9: Access the app in browser
minikube ip
# Suppose minikube ip = 192.168.49.2
# NodePort = 31766
# Then open: http://192.168.49.2:31766

# Step 10: Update the app
# If you change code or Dockerfile:
docker build -t devnet_dashboard:latest .
kubectl delete pod <devnet-dashboard-pod-name>

# Step 11: Verify
kubectl get pods
kubectl logs <pod-name>
kubectl get svc
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

type: minikube Dashboard
Note: This will show you the pods running inside your kubernetess cluster

Have fun!!!!!!!





