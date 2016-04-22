#!/bin/bash

# Caution: This is common script that is shared by more packages.
# If you need to do changes related to this particular collection,
# create a copy of this file instead of symlink.

THISDIR=$(dirname ${BASH_SOURCE[0]})
source ${THISDIR}/../../common/functions.sh

out=${out-/dev/stdout}

stPass="[PASSED]"
stFail="[FAILED]"

passed=0
failed=0

resDirAll=$(mktemp -d /tmp/db-ci-results-XXXXXX)

echo "Running tests for `basename $(readlink -f $THISDIR)` ..."

for tst in $(cat ${THISDIR}/enabled_tests|strip_comments)
do
    resDir="$resDirAll/$tst"
    mkdir -p "$resDir"

    ${THISDIR}/$tst/run.sh \
            2> >(tee "$resDir/err" | sed 's/^/\t/' >$out) \
            > >(tee "$resDir/out" | sed 's/^/\t/' >$out)
    retcode=$?

    echo "$retcode" >"$resDir/retcode"

    # check retcode
    if [ -f "$tst/retcode" ]
    then
        # if defined explicitly
        if echo "$retcode" | diff - "$tst/retcode" >/dev/null
        then
            state=$stPass
        else
            state=$stFail
        fi
    else
        #if not defined explicitly then 0 is expected
        if [ "$retcode" -eq "0" ]
        then
            state=$stPass
        else
            state=$stFail
        fi
    fi

    # if defined expected stdout, compare it with acctual stdout
    if [ -f "$tst/out" ] && [ "$state" != "$stFail" ]
    then
        if diff "$resDir/out" "$tst/out" >/dev/null
        then
            state=$stPass
        else
            state=$stFail
        fi
    fi

    # if defined expected stderr, compare it with acctual stderr
    if [ -f "$tst/err" ] && [ "$state" != "$stFail" ]
    then
        if diff "$resDir/err" "$tst/err" >/dev/null
        then
            state=$stPass
        else
            state=$stFail
        fi
    fi


    echo -e "$state\t$tst" | tee -a $resDirAll/tests.log


    if [ "$state" = "$stPass" ]
    then
        passed=$(($passed+1))

    else
        failed=$(($failed+1))
        failed_tests="$failed_tests $tst"
    fi
done

echo
echo "Test results summary:"
cat $resDirAll/tests.log

echo -e "\n$passed tests passed, $failed tests failed."

if [ "0$failed" -ne 0 ]
then
    echo -e "\nFailed tests:"
    for i in "$failed_tests"
    do
        echo -e "\t $i"
    done

    echo "Logs are stored in $resDirAll"
    echo "NOT ALL TESTS PASSED SUCCESSFULLY"

    # If some test went wrong return 10
    exit 10
fi

