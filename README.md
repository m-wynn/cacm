CACM -- Copy And Convert Music
==============================

**This was a fun project, but I'm replacing it with https://github.com/m-wynn/casm in Rust!**

This script copies and converts music.

It does a few things

1. Scans for music in the directories provided in the input file
2. Determines what's newer on the source (or doesn't exist on the destination)
3. Converts lossless and copies lossy files from the source to the destination

Best of all, it does this in a multithreaded way!

It's pretty great for putting music on your phone, when you don't have all
that storage for lossless files

Usage
-----

Run, for example:

```bash
./cacm.sh -f folders.txt -d /mnt/Internal\ shared\ storage/Music
```

Your folders.txt will look like:

```
#"source-folder"        "destination-folder"
"~/Music/Alan Jackson"  "Alan Jackson"
"~/Music/Daft Punk"     "Daft Punk"
"~/Music/Dal★Shabet"    "Dal★Shabet"
```

Files from the source folder will by copied into the full destination folder,
which includes the `-d` argument.

So `~/Music/Alan Jackson/` will end up in
`/mnt/Internal\ shared\ storage/Music/Alan Jackson`.

Troubleshooting
---------------

It turns out bash arrays aren't super performant, and the concurrency library
I'm using hangs when you're using more than 1000 files.  Just be patient when
it says "Determining what should be processed"

Also MTP is a disgusting protocol.  If you have a lot of cores, even over USB
3, you're going to see issues.  Increase your usb timeout if you can figure
out how.  Otherwise you might lose connection.

Currently it doesn't like converting files with double quotation marks in the
name

Contributing
------------

Go ham.  Just follow basic git best practices.  This was more of a learning
experience for me than anything else.
