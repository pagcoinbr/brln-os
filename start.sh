#!/bin/bash

sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io
sudo apt install -y nodejs npm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
npm init -y
npm install next@13.1.6 react@18.2.0 react-dom@18.2.0
npm install --save-dev jest
npm pkg set scripts.dev="next dev"
npm pkg set scripts.test="jest"