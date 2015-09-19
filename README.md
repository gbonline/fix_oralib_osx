# fix_oralib_osx

## What is this.

Until OS X 10.10 Yosemite, instant client works by setting `DYLD_LIBRARY_PATH`
or `DYLD_FALLBACK_LIBRARY_PATH`.
But since OS X 10.11 El Capitan, 'DYLD_*' environment variables are unset by
default for security reasons.

This script fixes dependent Oracle libraries in Orale instant client packages
and make them work without `DYLD_*` environment variables.

## Fix Oracle Instance Client

Note: You have no need to the following procedures if you put instant client libraries to `$HOME/lib` or `/usr/local/lib`.

### Install instant client.

Download 64-bit Instant client packages from [OTN](http://www.oracle.com/technetwork/topics/intel-macsoft-096467.html), unzip them and change to the unzipped directory.

```shell
unzip instantclient-basic-macos.x64-11.2.0.4.0.zip
# or unzip instantclient-basiclite-macos.x64-11.2.0.4.0.zip
unzip instantclient-sqlplus-macos.x64-11.2.0.4.0.zip
cd instantclient_11_2
```

`sqlplus` doesn't work at this time as follows:

```shell
$ ./sqlplus 
dyld: Library not loaded: /ade/dosulliv_sqlplus_mac/oracle/sqlplus/lib/libsqlplus.dylib
  Referenced from: /Volumes/share/fix_oralib/instantclient_11_2/./sqlplus
  Reason: image not found
Trace/BPT trap: 5
```

### Fix installed instant client.

Download fix_oralib.rb and execute it.

```shell
curl -O https://raw.githubusercontent.com/kubo/fix_oralib_osx/master/fix_oralib.rb
ruby fix_oralib.rb # apply to all files in the current directory by default.
```

`sqlplus` works now as follows:

```shell
$ ./sqlplus 

SQL*Plus: Release 11.2.0.4.0 Production on Sat Sep 19 15:36:04 2015

Copyright (c) 1982, 2013, Oracle.  All rights reserved.

Enter user-name: 
```

## Fix Third Party Applications

You need to fix Oracle Instance Client in advance.

If third party applications are built properly,
you have no need to do the followings.

### Executable which directly depends on Oracle libraries

Run the following command:

```shell
# if Oracle libraries are in '/opt/instantclient_11_2'
ruby fir_oralib.rb --ic_dir=/opt/instantclient_11_2 FILE_NAME_OF_EXECUTABLE
```
(Replace `FILE_NAME_OF_EXECUTABLE` with the real name.)

Note for developers who create C applications.

`fix_oralib.rb` should be applied to Oracle instant client before linkage.
`-Wl,-rpath,/opt/instantclient_11_2` should be set to `cc` or
`-rpath /opt/instantclient_11_2` should be set to `ld` on linkage.
(Change the path if Oracle client libraries are not in `/opt/instantclient_11_2`.)

### Executable which loads a module depending on Oracle libraries

The relation of the executable and the module is as that of ruby and
ruby-oci8. Whereas ruby doesn't depend on Oracle, ruby-oci8 depends
on Oracle. You need to get the full path of the executable in addition
to the module before running the following commands.

```shell
# Remember to set `-f` option for the executable which doesn't depends on Oracle.
ruby fir_oralib.rb -f --ic_dir=/opt/instantclient_11_2 FILE_NAME_OF_EXECUTABLE
ruby fir_oralib.rb --ic_dir=/opt/instantclient_11_2 FILE_NAME_OF_MODULE
```
(Replace `FILE_NAME_OF_EXECUTABLE` and `FILE_NAME_OF_MODULE` with
the real name respectively.)

Note for developers who create C modules.

`fix_oralib.rb` should be applied to Oracle instant client before linkage of a module.
`-Wl,-rpath,/opt/instantclient_11_2` should be set to `cc` or
`-rpath /opt/instantclient_11_2` should be set to `ld` on linkage of an executable.

If you are not a developer of the executable, write a document to execute the following command.
```shell
ruby fir_oralib.rb -f --ic_dir=/opt/instantclient_11_2 FILE_NAME_OF_EXECUTABLE
```

As for ruby-oci8, setting rpath to ruby itself is not required because
ruby-oci8 [intercepts](https://github.com/kubo/ruby-oci8/blob/92d596283f1451cc31b97f97b58fa4e2dea2e9c8/ext/oci8/osx.c#L9) `dlopen` function calls issued by `libclntsh.dylib`
to make `OCIEnvCreate()` work without setting rpath to the executable.
