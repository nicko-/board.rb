board.rb
========

board.rb is an extremely simple http bbs. board.rb (pronounced board-r-b) tries to keep it simple by doing away with usernames and passwords, sub-boards, permissions, rich-text, etc and focuses on _just_ the content.

Features...?
------------

 - No username/password authentication system. Users are identified through hashes of client and server side secrets.
 - No sub-boards. Threads can be attached with multiple tags and users discover new threads through these tags.
 - Plain text posts. board.rb is not an image hosting service.
