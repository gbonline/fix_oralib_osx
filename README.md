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

### Download 64-bit Instant client packages from http://www.oracle.com/technetwork/topics/intel-macsoft-096467.html, unzip them and change to the unzipped directory.

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

### Download fix_oralib.rb and execute it.

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

## Fix Third party applications

### executable which directly links Oracle libraries.

If it doesn't work by loading error of Oracle libraries, run
the following command:

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

### loadable module which links Oracle libraries.

If it doesn't work by loading error of Oracle libraries, run
the following command:

```shell
# if Oracle libraries are in '/opt/instantclient_11_2'
ruby fir_oralib.rb -f --ic_dir=/opt/instantclient_11_2 FILE_NAME_OF_EXECUTABLE
ruby fir_oralib.rb --ic_dir=/opt/instantclient_11_2 FILE_NAME_OF_LODABLE_MODULE
```
(Replace `FILE_NAME_OF_EXECUTABLE` and FILE_NAME_OF_LODABLE_MODULE with
the real name respectively.)

Note for developers who create C lodable modules.

`fix_oralib.rb` should be applied to Oracle instant client before linkage of loadable module.
`-Wl,-rpath,/opt/instantclient_11_2` should be set to `cc` or
`-rpath /opt/instantclient_11_2` should be set to `ld` on linkage of executable.

If you are not a developer of executable, write a document to execute the following command.
```shell
ruby fir_oralib.rb -f --ic_dir=/opt/instantclient_11_2 FILE_NAME_OF_EXECUTABLE
```
