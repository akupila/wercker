#!/bin/bash

# This is a shell script to run a bunch of regression tests that require
# running sentcli in a fully docker-enabled environment. They'll eventually
# be moved into a golang test package.
wercker=./wercker
workingDir=./.werckertests
testsDir=./tests/projects

# Make sure we have a working directory
mkdir -p $workingDir
if [ ! -e "$wercker" ]; then
  go build
fi


basicTest() {
  testName=$1
  shift
  printf "testing %s... " "$testName"
  $wercker $@ --working-dir $workingDir > "${workingDir}/${testName}.log"
  if [ $? -ne 0 ]; then
    printf "failed\n"
    cat "${workingDir}/${testName}.log"
    return 1
  else
    printf "passed\n"
  fi
  return 0
}

basicTestFail() {
  testName=$1
  shift
  printf "testing %s... " "$testName"
  $wercker $@ --working-dir $workingDir > "${workingDir}/${testName}.log"
  if [ $? -ne 1 ]; then
    printf "failed\n"
    cat "${workingDir}/${testName}.log"
    return 1
  else
    printf "passed\n"
  fi
  return 0
}

testDirectMount() {
  echo -n "testing direct-mount..."
  testDir=$testsDir/direct-mount
  testFile=${testDir}/testfile
  > $testFile
  echo "hello" > $testFile
  logFile="${workingDir}/direct-mount.log"
  $wercker build $testDir --direct-mount --working-dir $workingDir > $logFile
  contents=$(cat ${testFile})
  if [ "$contents" == 'world' ]
      then echo "passed"
      return 0
  else
      echo 'failed'
      cat $logFile
      return 1
  fi
}


runTests() {
  basicTest "source-path" build $testsDir/source-path || return 1
  basicTest "test local services" --debug build  $testsDir/local-service/service-consumer || return 1
  basicTest "test deploy" deploy $testsDir/deploy-no-targets || return 1
  basicTest "test deploy target" deploy --deploy-target test $testsDir/deploy-targets || return 1
  basicTest "test shellstep" build --enable-dev-steps $testsDir/shellstep
  basicTest "test after steps" build --pipeline build_true $testsDir/after-steps-fail || return 1

  # this one will fail but we'll grep the log for After-step passed: test
  basicTestFail "test after steps fail" --no-colors build --pipeline build_fail $testsDir/after-steps-fail || return 1
  grep -q "After-step passed: test" "${workingDir}/test after steps fail.log" || return 1

  # make sure we get some human understandable output if the wercker file is wrong
  basicTestFail "test empty wercker file" build $testsDir/invalid-config || return 1
  grep -q "Your wercker.yml is empty." "${workingDir}/test empty wercker file.log" || return 1

  testDirectMount || return 1
}

runTests
rm -rf $workingDir
