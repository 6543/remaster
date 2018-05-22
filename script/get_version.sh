#!/bin/bash

grep '@version ' src/remaster.sh | cut -d " " -f 2
