#! /bin/sh
ruby -I.. ../gonzui-db > /dev/null || exit 1
ruby -I.. ../gonzui-import > /dev/null || exit 1
ruby -I.. ../gonzui-remove > /dev/null || exit 1
ruby -I.. ../gonzui-search > /dev/null || exit 1

exit 0
