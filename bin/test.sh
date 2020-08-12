#!/usr/bin/env bash

RUBYOPT='-rbundler/setup -rrbs/test/setup' RBS_TEST_TARGET="RrToRspecConverter::*" RBS_TEST_LOGLEVEL=debug RBS_TEST_OPT="-I sig" bundle exec rspec 
