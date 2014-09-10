BEGIN TRANSACTION;
CREATE TABLE `posts` (
  `id`	INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  `author`	TEXT NOT NULL,
  `content`	TEXT NOT NULL,
  `date`    NUMERIC NOT NULL,
  `tags`    TEXT NOT NULL,
  `in_reply_to`	NUMERIC
);
CREATE TABLE `auth` (
  `server_secret`	TEXT NOT NULL,
  `hash`	TEXT NOT NULL
);
COMMIT;