CREATE TABLE `boardrb`.`posts` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `author` VARCHAR(32) NOT NULL,
  `content` TEXT NOT NULL,
  `date` INT NOT NULL,
  `last_update` INT NOT NULL,
  `tags` TEXT NOT NULL,
  `in_reply_to` INT NULL,
  PRIMARY KEY (`id`));
CREATE TABLE `boardrb`.`auth` (
  `hash` VARCHAR(32) NOT NULL,
  `server_secret` TEXT NOT NULL,
  PRIMARY KEY (`hash`));
CREATE TABLE `boardrb`.`userconfig` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `user` VARCHAR(32) NOT NULL,
  `key` TEXT NOT NULL,
  `value` TEXT NOT NULL,
  PRIMARY KEY (`id`));
