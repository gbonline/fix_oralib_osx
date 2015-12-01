# fix_oralib_osx

Until OS X 10.10 Yosemite, instant client works by setting `DYLD_LIBRARY_PATH`
or `DYLD_FALLBACK_LIBRARY_PATH`.
But since OS X 10.11 El Capitan, `DYLD_*` environment variables are unset by
default for security reasons.

This script fixes dependent Oracle libraries in Oracle instant client packages
and make them work without `DYLD_*` environment variables.

## Fix Oracle Instance Client

### Install instant client.

Download 64-bit Instant client packages from [OTN](http://www.oracle.com/technetwork/topics/intel-macsoft-096467.html), unzip them and change to the unzipped directory.

```shell
unzip instantclient-basic-macos.x64-11.2.0.4.0.zip
# or unzip instantclient-basiclite-macos.x64-11.2.0.4.0.zip
unzip instantclient-sqlplus-macos.x64-11.2.0.4.0.zip
cd instantclient_11_2
```

sqlplus doesn't work at this time as follows:

```shell
$ ./sqlplus 
dyld: Library not loaded: /ade/dosulliv_sqlplus_mac/oracle/sqlplus/lib/libsqlplus.dylib
  Referenced from: /opt/instantclient_11_2/./sqlplus
  Reason: image not found
Trace/BPT trap: 5
```

### Fix installed instant client.

Note: You have no need to the following procedures if you put instant client libraries to `$HOME/lib` or `/usr/local/lib`.

Download `fix_oralib.rb` and execute it.

```shell
curl -O https://raw.githubusercontent.com/kubo/fix_oralib_osx/master/fix_oralib.rb
ruby fix_oralib.rb # apply to all files in the current directory.
```

sqlplus works now as follows:

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
`fix_oralib.rb` doesn't change unrelated files.

```shell
$ find /path/to/application/top/directory -type f | xargs ruby fix_oralib.rb --ic_dir=/opt/instantclient_11_2
```

### Fix compilation steps

If you have source code and can make binary files, do the followings.

`fix_oralib.rb` should be applied to Oracle instant client before compilation.

`-Wl,-rpath,/opt/instantclient_11_2` should be set to `cc` or
`-rpath /opt/instantclient_11_2` should be set to `ld` on linkage.
(If you put your executable in a relative path of instant client, you can use
`@loader_path` + "relative path to instant client" such as `@loader_path/../lib`
instead of an absolute path.)

## What this does.

`fix_oralib.rb` changes the following information recorded in mach-o binary files.
* identification name
* install names
* rpaths

The directory names in the identification name and install names are
replaced with `@rpath` if their file names are that of Oracle
libraries. `@loader_path` is added as a rpath if the target file depends
on Oracle libraries and is in the same directory with Oracle
libraries. The absolute path of the directory containing Oracle
libraries is added as a rpath if the target file depends on Oracle
libraries and is in a directory different with Oracle libraries.

Don't confuse `@rpath` with rpath. `@rpath` is a special name used in
identification and install names. rpath is a directory name
replaced with `@rpath` at runtime to find the real path of install
names.

## Why install names and rpaths are changed.

The original sqlplus has install names only.

Note: `otool -D filename` prints the identification name. `otool -L filename` prints the identification
name *and* install names. `otool -l filename | grep -A2 LC_RPATH | grep path` prints rpaths.

```shell
$ otool -D sqlplus
sqlplus:
$ otool -L sqlplus
sqlplus:
	/ade/dosulliv_sqlplus_mac/oracle/sqlplus/lib/libsqlplus.dylib (compatibility version 0.0.0, current version 0.0.0)
	/ade/b/2475221476/oracle/rdbms/lib/libclntsh.dylib.11.1 (compatibility version 0.0.0, current version 0.0.0)
	/ade/b/2475221476/oracle/ldap/lib/libnnz11.dylib (compatibility version 0.0.0, current version 0.0.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 159.1.0)
$ otool -l sqlplus | grep -A2 LC_RPATH | grep path
```

When sqlplus runs, it tries to use `libsqlplus.dylib` in `DYLD_LIBRARY_PATH`.
If it fails, it tries to use the full path `/ade/dosulliv_sqlplus_mac/oracle/sqlplus/lib/libsqlplus.dylib`
and then use `libsqlplus.dylib` in `DYLD_FALLBACK_LIBRARY_PATH`.

However `DYLD_LIBRARY_PATH` and `DYLD_FALLBACK_LIBRARY_PATH` are unset on
OS X 10.11 El Capitan. Thus sqlplus runs only when `libsqlplus.dylib` is
in `/ade/dosulliv_sqlplus_mac/oracle/sqlplus/lib/` or in the default
path of `DYLD_FALLBACK_LIBRARY_PATH`: `$HOME/lib`, `/usr/local/lib`, `/lib`
or `/usr/lib`.

`fix_oralib.rb` changes three install names and adds one rpath as follows:

```shell
$ otool -D sqlplus
sqlplus:
$ otool -L sqlplus
sqlplus:
	@rpath/libsqlplus.dylib (compatibility version 0.0.0, current version 0.0.0)
	@rpath/libclntsh.dylib.11.1 (compatibility version 0.0.0, current version 0.0.0)
	@rpath/libnnz11.dylib (compatibility version 0.0.0, current version 0.0.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 159.1.0)
$ otool -l sqlplus | grep -A2 LC_RPATH | grep path
         path @loader_path (offset 12)
```

`@rpath` is replaced with rpaths recorded in sqlplus one by one.
It is `@loader_path` only in this case. `@loader_path` is replaced with
the directory containing sqlplus. Thus sqlplus can find
`libsqlplus.dylib` in the directory containing sqlplus.

Other files in instant client are changed in the same way.
So the fixed instant client can be moved to any directory as long as
all files are in a directory.

Third party applications are usually in a directory different with
Oracle libraries. So that the absolute path of the directory
containing Oracle libraries should be added as a rpath.

## Why the identification name is changed.

The original `libclntsh.dylib.11.1` has the following identification name.

```shell
$ otool -D libclntsh.dylib.11.1
libclntsh.dylib.11.1:
/ade/b/3071542110/oracle/rdbms/lib/libclntsh.dylib.11.1
```

The identification name is used as an install name in a binary and it
can be changed by `install_name_tool` command after compilation as follows.

```shell
$ otool -D /opt/instantclient_11_2/libclntsh.dylib.11.1
/opt/instantclient_11_2/libclntsh.dylib.11.1:
/ade/b/3071542110/oracle/rdbms/lib/libclntsh.dylib.11.1
$ cc -o oraclapp oracleapp.c -I/opt/instantclient_11_2/sdk/include -L/opt/instantclient_11_2 -Wl,-rpath,/opt/instantclient_11_2 -lclntsh.
$ otool -L oraclapp
oraclapp:
	/ade/b/2475221476/oracle/rdbms/lib/libclntsh.dylib.11.1 (compatibility version 0.0.0, current version 0.0.0)
        ...
$ install_name_tool -change /ade/b/2475221476/oracle/rdbms/lib/libclntsh.dylib.11.1 @rpath/libclntsh.dylib.11.1 oracleapp
$ otool -L oraclapp
oraclapp:
	@rpath/libclntsh.dylib.11.1 (compatibility version 0.0.0, current version 0.0.0)
        ...
```

However changing the identification in advance make compilation steps simple.

```shell
$ otool -D /opt/instantclient_11_2/libclntsh.dylib.11.1
/opt/instantclient_11_2/libclntsh.dylib.11.1:
@rpath/libclntsh.dylib.11.1
$ cc -o oraclapp oracleapp.o -I/opt/instantclient_11_2/sdk/include -L/opt/instantclient_11_2 -Wl,-rpath,/opt/instantclient_11_2 -lclntsh.
$ otool -L oraclapp
oraclapp:
	@rpath/libclntsh.dylib.11.1 (compatibility version 0.0.0, current version 0.0.0)
        ...
```

## Absolute path option

`fix_oralib.rb` uses the absolute path of instant client directory
instead of `@rpath` if `-a` or `--absolute-path` option is specified.

```shell
$ pwd
/opt/instantclient_11_2
$ ruby fix_oralib.rb --absolute-path
$ otool -D sqlplus
sqlplus:
$ otool -L sqlplus
sqlplus:
	/opt/instantclient_11_2/libsqlplus.dylib (compatibility version 0.0.0, current version 0.0.0)
	/opt/instantclient_11_2/libclntsh.dylib.11.1 (compatibility version 0.0.0, current version 0.0.0)
	/opt/instantclient_11_2/libnnz11.dylib (compatibility version 0.0.0, current version 0.0.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 159.1.0)
$ otool -l sqlplus | grep -A2 LC_RPATH | grep path
```

`fix_oralib.rb` doesn't set a rpath because install names doesn't
include `@rpath`. The only exception is `libclntsh.dylib.11.1`. The
OCI function `OCIEnvCreate` fails if rpath isn't set to point to the
directory containing `libclntsh.dylib.11.1`.

Absolute path may be better than `@rpath` on compilation.

```shell
$ otool -D /opt/instantclient_11_2/libclntsh.dylib.11.1
/opt/instantclient_11_2/libclntsh.dylib.11.1:
/opt/instantclient_11_2/libclntsh.dylib.11.1
$ cc -o oraclapp oracleapp.o -I/opt/instantclient_11_2/sdk/include -L/opt/instantclient_11_2 -lclntsh.
$ otool -L oraclapp
oraclapp:
	/opt/instantclient_11_2/libclntsh.dylib.11.1 (compatibility version 0.0.0, current version 0.0.0)
        ...
```

When the identification name is an absolute path, the install name
embedded in a compiled binary is also an absolute path. You have
no need to set `-Wl,-rpath,/opt/instantclient_11_2` to `cc` to set
rpath.

However I chose `@rpath` because instant client packages may be
installed anywhere. If I were employed by Oracle and could fix the
identification and install names for the next instant client release,
I would use `@rpath`. Otherwise, instant client doesn't work on El
Capitan without changing install names.
