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

Download `fix_oralib.rb` and execute it.

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

Note that the fixed instant client can be moved to any directory as long as
all files are in a directory.

## Fix Third Party Applications

You need to fix Oracle Instance Client in advance.

If third party applications are built properly,
you have no need to do the followings.

In this section, assume that `/opt/instantclient_11_2` is the instant client directory

### Fix compiled files

If you don't have source code and cannot make binary files,
the easiest way is applying `fix_oralib.rb` to all files.
`fix_oralib.rb` doesn't change unrelated files without `-f` option.

```shell
$ find /path/to/application/top/directory -type f | xargs ruby fix_oralib.rb --ic_dir=/opt/instantclient_11_2
```

If the application executable file doesn't depends on Oracle directly,
you need to apply `fix_oralib.rb` with `-f` option.

```shell
$ ruby fix_oralib.rb -f --ic_dir=/opt/instantclient_11_2 /path/to/executable/file
```

### Fix compilation steps

If you have source code and can make binary files, do the followings.

`fix_oralib.rb` should be applied to Oracle instant client before compilation.

`-Wl,-rpath,/opt/instantclient_11_2` should be set to `cc` or
`-rpath /opt/instantclient_11_2` should be set to `ld` on linkage of executable files.

For example `rpath` must be set to the executable `A` in the following case.
* `A` is an executable file and doesn't depend on Oracle.
* `B` is an Oracle interface of `A` and depends on Oracle.

Though it is ideal that `rpath` is set to 'B' only, it can't.
If `rpath` isn't set to `A`, `libclntsh.dylib` cannot find the full path
of self and `OCIEnvCreate()` fails.

The only exception is `ruby-oci8` at the present time. It [intercepts](https://github.com/kubo/ruby-oci8/blob/92d596283f1451cc31b97f97b58fa4e2dea2e9c8/ext/oci8/osx.c#L9) `dlopen`
function calls issued by `libclntsh.dylib` to make `OCIEnvCreate()`
work without setting `rpath` to `ruby` itself.
