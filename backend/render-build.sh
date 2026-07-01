#!/usr/bin/env bash
# exit on error
set -o errexit

# Install project dependencies
npm install

# Explicitly download Chrome browser for Puppeteer to run in Render's environment
# We use the same cache directory that Render supports and persists
export PUPPETEER_CACHE_DIR=/opt/render/.cache/puppeteer
npx puppeteer browsers install chrome
