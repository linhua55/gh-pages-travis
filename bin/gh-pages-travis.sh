#!/bin/bash
set -e
 
# Deploy built docs from this branch
: ${DEPLOY_BRANCH:=master}
 
# Deploy built docs from this directory
: ${SOURCE_DIR:=doc}
 
# Deploy built docs to this branch
: ${TARGET_BRANCH:=gh-pages}
 
# Use this SSH key to push to github
: ${SSH_KEY:=id_rsa}
 
# Use this git user name in commits
: ${GIT_NAME:=travis}
 
# Use this git user email in commits
: ${GIT_EMAIL:=deploy@travis-ci.org}
 
if [ ! -d "$SOURCE_DIR" ]; then
  echo "SOURCE_DIR ($SOURCE_DIR) does not exist, build the source directory before deploying"
  exit 1
fi
 
REPO=$(git config remote.origin.url)
 
if [ -n "$TRAVIS_BUILD_ID" ]; then
  # When running on Travis we need to use SSH to deploy to GitHub
  #
  # The following converts the repo URL to an SSH location,
  # adds the SSH key and sets up the Git config with
  # the correct user name and email (globally as this is a
  # temporary travis environment)
  #
  echo DEPLOY_BRANCH: $DEPLOY_BRANCH
  echo SOURCE_DIR: $SOURCE_DIR
  echo TARGET_BRANCH: $TARGET_BRANCH
  echo SSH_KEY: $SSH_KEY
  echo GIT_NAME: $GIT_NAME
  echo GIT_EMAIL: $GIT_EMAIL
  if [ "$TRAVIS_BRANCH" != "$DEPLOY_BRANCH" ]; then
    echo "Travis should only deploy from the DEPLOY_BRANCH ($DEPLOY_BRANCH) branch"
    exit 0
  else
    if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
      echo "Travis should not deploy from pull requests"
      exit 0
    else
      # switch both git and https protocols as we don't know which travis
      # is using today (it changed!)
      REPO=${REPO/git:\/\/github.com\//git@github.com:}
      REPO=${REPO/https:\/\/github.com\//git@github.com:}
      
      chmod 600 $SSH_KEY
      eval `ssh-agent -s`
      ssh-add $SSH_KEY
      git config --global user.name "$GIT_NAME"
      git config --global user.email "$GIT_EMAIL"
    fi
  fi
fi
 
REPO_NAME=$(basename $REPO)
TARGET_DIR=$(mktemp -d /tmp/$REPO_NAME.XXXX)
REV=$(git rev-parse HEAD)
git clone --branch ${TARGET_BRANCH} ${REPO} ${TARGET_DIR}
rsync -rt --delete --exclude=".git" --exclude=".travis.yml" $SOURCE_DIR/ $TARGET_DIR/
cd $TARGET_DIR
git add -A .
git commit --allow-empty -m "Built from commit $REV"
git push $REPO $TARGET_BRANCH
