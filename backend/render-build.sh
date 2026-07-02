#!/usr/bin/env bash
# exit on error
set -o errexit

# Install project dependencies
npm install

# Explicitly download Chrome browser inside the project directory so it is copied to the runtime container
export PUPPETEER_CACHE_DIR=$(pwd)/.cache/puppeteer
npx puppeteer browsers install chrome
