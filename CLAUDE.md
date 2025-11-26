# Project Brief

I am looking at the SURFSENSE project. I want to create a docker environment. The project contains a docker-compose.yml in the root and three .env files. I need to configure the .env files.

Both the backend and the frontend are set to build at compose time and have their custom .env files set with the env_file attrib.

I want the images to be prebuilt and deployed to a Docker registry. They should have a version number in the tag. The backend has a version number in pyproject.toml which we can use. The surfsense_web has a version number in package.json.

I also want the docker volumes to be "normal" directories. Currently they are specified as docker volumes.

Since I don't own this repository I have created another branch which we'll work from. I want all the changes we make to be in the directory ./deploy.

My main goal is to run this in production with a single .env file and a docker-compose.yml. So the result of this main task should be:

* a single merged .env file in ./deploy
* a docker-compose.yml in ./deploy
* volume directories in ./deploy
* scripts that build both the images and deploys it to the repo
* docker-compose.yml should reference the repo images

Notes:
* check for conflicting variable names in the .env files -- maybe they have the same meaning, maybe they don't
* add a .gitignore to ./deploy:
  - ignore the volume directories
  - ignore the .env

## Workflow

Split the main task into multiple tasks.
Create a sub branch for each task with the name {index}-{short-description}.
When done with a task ask the user if we should continue.

