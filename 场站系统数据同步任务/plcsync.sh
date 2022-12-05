#!/bin/bash

current_path=$(cd `dirname $0`; pwd)
cd $current_path

./plctoscada.sh && ./scadaplctoother.sh
