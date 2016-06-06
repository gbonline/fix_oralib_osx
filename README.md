# fix_oralib_osx

`fix_oralib.rb` has been obsolete since [Oracle Instant Client 12.1 for OS X][download] was released.
The 12.1 client supports OS X 10.11 El Capitan, 10.10 Yosemite, and 10.9 Mavericks
and can connect to Oracle Database 10.2 or later.

Look at [this document][inst] to install 12.1.

The old `fix_oralib.rb` document was renamed to `OLD_README.md`.

## Note for third party applications

Third party applications depending on the 12.1 client should link with `-rpath`.
If an application is built without `-rpath`, the application fails to run with
the following error if the 12.1 client is not installed in `/lib`, `/usr/lib`,
`/usr/local/lib` or `~/lib`.

```shell
$ application_file_name
dyld: Library not loaded: @rpath/libclntsh.dylib.12.1
  Referenced from: /path/to/application_file_name
  Reason: image not found
Trace/BPT trap: 5
```

In this case, run the following command to add `rpath` to the application.

```shell
$ install_name_tool -add_rpath /directory/name/containing/oracle/client application_file_name
```

[ruby-oci8][] and [node-oracledb][] add `-rpath` to linker options by default.

As for [cx_Oracle][], you should add the environment variable `FORCE_RPATH` to link with `-rpath` at compilation time.
(You have no need to set the environment variable at runtime.)

[download]: http://www.oracle.com/technetwork/topics/intel-macsoft-096467.html
[inst]: http://www.oracle.com/technetwork/topics/intel-macsoft-096467.html#ic_osx_inst
[ruby-oci8]: http://www.rubydoc.info/github/kubo/ruby-oci8
[node-oracledb]: https://github.com/oracle/node-oracledb
[cx_Oracle]: https://bitbucket.org/anthony_tuininga/cx_oracle/
