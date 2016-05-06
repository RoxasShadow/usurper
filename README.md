Usurper
=======

Usurper detects every screenshot taken by OSX and uploads them
to your server via [SCP](https://en.wikipedia.org/wiki/Secure_copy) or
to POMF-like services as [uguu.se](https://uguu.se) and [jii.moe](https://jii.moe).

A system notification will update you about the status of the
uploading process and finally the screenshot URL will be copied
into the clipboard.

Usage
-----

`$ swift usurper.swift`

I run this script at boot time via *Automator.app*.

Configuration
-------------

Out of the box this script works with uguu.se only. If you want to switch to jii.moe or
SCP please open the script and follow the instructions.
