#!/bin/bash

scp -i "$MINE_POTATO_KEY" "$1" "$MINE_POTATO_CONNECTION":"$2/$1"
