-- phpMyAdmin SQL Dump
-- version 5.1.2
-- https://www.phpmyadmin.net/
--
-- Gép: localhost:3306
-- Létrehozás ideje: 2026. Ápr 09. 09:53
-- Kiszolgáló verziója: 5.7.24
-- PHP verzió: 8.3.1

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Adatbázis: `vizsgaremekticketz`
--
CREATE DATABASE IF NOT EXISTS `vizsgaremekticketz` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;
USE `vizsgaremekticketz`;

DELIMITER $$
--
-- Eljárások
--
DROP PROCEDURE IF EXISTS `cancel_full_order`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `cancel_full_order` (IN `p_order_id` INT)   BEGIN

DECLARE v_exists INT;
SELECT COUNT(*) INTO v_exists FROM orders WHERE id = p_order_id;

IF v_exists = 0 THEN
	SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order not found.';
END IF;

START TRANSACTION;

UPDATE tickets t 
JOIN bought_tickets bt ON bt.ticket_id = t.id
SET t.status = 'available' WHERE bt.order_id = p_order_id;

DELETE FROM bought_tickets WHERE oder_id = p_order_id;

UPDATE orders 
SET status = 'cancelled' WHERE id = p_order_id;

COMMIT;

END$$

DROP PROCEDURE IF EXISTS `cancel_reservation`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `cancel_reservation` (IN `p_ticket_id` INT)   BEGIN

UPDATE tickets SET status = 'available' WHERE id = p_ticket_id AND status = 'reserved';

END$$

DROP PROCEDURE IF EXISTS `create_admin_by_email`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `create_admin_by_email` (IN `p_email` VARCHAR(190), IN `p_position` VARCHAR(100), IN `p_notes` TEXT)   BEGIN

DECLARE v_user_id INT;

SELECT id INTO v_user_id FROM users WHERE email = p_email LIMIT 1;

IF v_user_id IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User not found for this email.'; 
END IF;

IF EXISTS (SELECT 1 FROM admins WHERE user_id = v_user_id) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This user is already an admin.';
END IF;

UPDATE users
SET role = 'admin' WHERE id = v_user_id;

INSERT INTO admins (user_id, position, notes)
VALUES (v_user_id, p_position, p_notes);

END$$

DROP PROCEDURE IF EXISTS `create_cinema`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `create_cinema` (IN `p_name` VARCHAR(200), IN `p_city` VARCHAR(100), IN `p_address` VARCHAR(255), IN `p_phone` VARCHAR(50), IN `p_website` VARCHAR(200))   BEGIN

INSERT INTO cinemas (name, city, address, phone, website)
VALUES (p_name, p_city, p_address, p_phone, p_website);

END$$

DROP PROCEDURE IF EXISTS `create_discount`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `create_discount` (IN `p_code` VARCHAR(50), IN `p_description` VARCHAR(255), IN `p_discount_type` ENUM('percent','fixed'), IN `p_value` DECIMAL(10,2), IN `p_valid_from` DATE, IN `p_valid_to` DATE, IN `p_min_total` DECIMAL(10,2))   BEGIN

INSERT INTO discounts (code, description, discount_type, value, valid_from, valid_to, min_total, is_active )
VALUES (p_code, p_description, p_discount_type, p_value, p_valid_from, p_valid_to, p_min_total, 1);

END$$

DROP PROCEDURE IF EXISTS `create_full_order`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `create_full_order` (IN `p_user_id` INT, IN `p_ticket_id` INT)   BEGIN

DECLARE v_price DECIMAL (10,2);
DECLARE v_status VARCHAR(20);
DECLARE v_order_id INT;

SELECT price, status INTO v_price, v_status FROM tickets
WHERE id = p_ticket_id
LIMIT 1;

IF v_price IS NULL THEN
	SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "Ticket not found.";
END IF;

IF v_status <> 'available' THEN
	SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "Ticket is not available.";
END IF;


START TRANSACTION;

INSERT INTO orders (user_id, total, status, title)
VALUES(p_user_id, v_price, 'paid', 'Online order');

SET v_order_id = LAST_INSERT_ID();

INSERT INTO bought_tickets (order_id, ticket_id, price)
VALUES(v_order_id, p_ticket_id, v_price);

UPDATE tickets
SET STATUS = 'paid' WHERE id = p_ticket_id;

COMMIT;

END$$

DROP PROCEDURE IF EXISTS `create_order_for_user_and_event`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `create_order_for_user_and_event` (IN `p_email` VARCHAR(190), IN `p_event_title` VARCHAR(200), IN `p_status` VARCHAR(20))   BEGIN

DECLARE v_user_id INT;
DECLARE v_ticket_id INT;
DECLARE v_price DECIMAL(10,2);

SELECT id INTO v_user_id FROM users WHERE email = p_email LIMIT 1;

IF v_user_id IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User not found for this email.';
END IF;

SELECT t.id, t.price INTO v_ticket_id, v_price FROM tickets t JOIN events e ON e.id = t.event_id WHERE e.title = p_event_title AND t.status = 'available' LIMIT 1;

IF v_ticket_id is NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No available ticket for this event.';
END IF;

START TRANSACTION;

INSERT INTO orders (user_id, total, status) VALUES (v_user_id, v_price, status);

INSERT INTO bought_tickets (order_id, ticket_id, price) VALUES (LAST_INSERT_ID(), v_ticket_id, v_price);

COMMIT;

END$$

DROP PROCEDURE IF EXISTS `create_theatre`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `create_theatre` (IN `p_name` VARCHAR(200), IN `p_city` VARCHAR(100), IN `p_address` VARCHAR(255), IN `p_phone` VARCHAR(50), IN `p_website` VARCHAR(200))   BEGIN

INSERT INTO theatres (name, city, address, phone, website)
VALUES (p_name, p_city, p_address, p_phone, p_website);

END$$

DROP PROCEDURE IF EXISTS `get_active_discount_by_code`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `get_active_discount_by_code` (IN `p_code` VARCHAR(50))   BEGIN

SELECT id, code, description, discount_type, value, valid_from, valid_to, min_total, is_active, created FROM discounts WHERE code = p_code AND is_active = 1 AND (valid_from IS NULL OR valid_from <= CURDATE()) AND (valid_to IS NULL OR valid_to >= CURDATE());

END$$

DROP PROCEDURE IF EXISTS `get_all_admins`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `get_all_admins` ()   BEGIN

SELECT a.id AS admin_id,
	   u.id AS user_id,
       u.name AS admin_name,
       u.email AS admin_email,
       u.role AS user_role,
       a.position,
       a.notes,
       a.created FROM admins a JOIN users u ON u.id = a.user_id ORDER BY a.created DESC;
       
END$$

DROP PROCEDURE IF EXISTS `get_cinema_events`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `get_cinema_events` (IN `p_cinema_id` INT)   BEGIN

SELECT e.id AS event_id, e.title, e.room, e.start, e.end, e.seats FROM events e WHERE e.cinema_id = p_cinema_id ORDER BY e.start;

END$$

DROP PROCEDURE IF EXISTS `get_event_full_data`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `get_event_full_data` (IN `p_event_id` INT)   BEGIN

SELECT e.id, e.title, e.room, e.type, e.start, e.end, e.seats,
SUM(CASE WHEN t.status = 'available' THEN 1 ELSE 0 END) AS available_tickets,
SUM(CASE WHEN t.status = 'reserved' THEN 1 ELSE 0 END) AS reserved_tickets,
SUM(CASE WHEN t.status = 'sold' THEN 1 ELSE 0 END) AS sold_tickets FROM events e 

LEFT JOIN tickets t ON t.event_id = e.id WHERE e.id = p_event_id;


END$$

DROP PROCEDURE IF EXISTS `get_event_revenue`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `get_event_revenue` (IN `p_event_id` INT)   BEGIN

SELECT e.title AS event_title, COUNT(bt.id) AS sold_tickets_count, IFNULL(SUM(bt.price),0) AS total_revenue FROM events e 
LEFT JOIN tickets t ON t.event_id = e.id
LEFT JOIN bought_tickets bt ON bt.ticket_id = t.id WHERE e.id = p_event_id;

END$$

DROP PROCEDURE IF EXISTS `get_favorites_for_user`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `get_favorites_for_user` (IN `p_user_id` INT)   BEGIN

SELECT f.id AS favorite_id,  e.id AS event_id, e.title, e.type, e.start, e.end, e.room, f.created AS favorited_at FROM favorites f JOIN events e ON e.id = f.event_id WHERE f.user_id = p_user_id ORDER BY e.start;

END$$

DROP PROCEDURE IF EXISTS `get_theatre_events`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `get_theatre_events` (IN `p_theatre_id` INT)   BEGIN

SELECT e.id AS event_id, e.title, e.room, e.start, e.end, e.seats FROM events e WHERE e.theatre_id = p_theatre_id ORDER BY e.start;

END$$

DROP PROCEDURE IF EXISTS `get_user_orders`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `get_user_orders` (IN `p_user_email` VARCHAR(190))   BEGIN

SELECT  o.id AS order_id, o.total, o.status, o.created FROM orders o JOIN users u ON u.id = o.user_id WHERE u.email = p_user_email ORDER BY o.created DESC;

END$$

DROP PROCEDURE IF EXISTS `list_tickets_for_event`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `list_tickets_for_event` (IN `p_event_id` INT)   BEGIN 
	SELECT t.id AS ticket_id, t.seat_label, t.price, t.status
     FROM tickets t WHERE t.event_id = p_event_id
		ORDER BY t.seat_label;
      
END$$

DROP PROCEDURE IF EXISTS `mark_ticket_as_sold`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `mark_ticket_as_sold` (IN `p_ticket_id` INT)   BEGIN

UPDATE tickets SET status = 'sold' WHERE id = p_ticket_id AND status IN ('reserved', 'available');


END$$

DROP PROCEDURE IF EXISTS `remove_admin_by_email`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `remove_admin_by_email` (IN `p_email` VARCHAR(190))   BEGIN

DECLARE v_user_id INT;
SELECT id INTO v_user_id FROM users WHERE email = p_email LIMIT 1;

IF v_user_id IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User not found for this email.';
END IF;

IF NOT EXISTS (SELECT 1 FROM admins WHERE user_id = v_user_id) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This user is not an admin.';
END IF;

START TRANSACTION;
DELETE FROM admins WHERE user_id = v_user_id;

UPDATE users
SET role = 'user' WHERE id = v_user_id;

COMMIT;
END$$

DROP PROCEDURE IF EXISTS `reserve_ticket`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `reserve_ticket` (IN `p_ticket_id` INT)   BEGIN

UPDATE tickets SET status = 'reserved' WHERE id = p_ticket_id AND status = 'available';


END$$

DROP PROCEDURE IF EXISTS `ticket_statistics`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `ticket_statistics` (IN `p_event_title` VARCHAR(200))   BEGIN

SELECT SUM(CASE WHEN status = 'available' THEN 1 ELSE 0 END) AS available,
	SUM(CASE WHEN status = 'reserved' THEN 1 ELSE 0 END) AS reserved,
    SUM(CASE WHEN status = 'sold' THEN 1 ELSE 0 END) AS sold 
    FROM tickets t JOIN events e ON e.id = t.event_id WHERE e.title = p_event_title;
   

END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `admins`
--

DROP TABLE IF EXISTS `admins`;
CREATE TABLE `admins` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `position` varchar(100) DEFAULT NULL,
  `notes` text,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `bought_tickets`
--

DROP TABLE IF EXISTS `bought_tickets`;
CREATE TABLE `bought_tickets` (
  `id` int(11) NOT NULL,
  `order_id` int(11) NOT NULL,
  `ticket_id` int(11) NOT NULL,
  `price` decimal(10,2) NOT NULL,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `cinemas`
--

DROP TABLE IF EXISTS `cinemas`;
CREATE TABLE `cinemas` (
  `id` int(11) NOT NULL,
  `name` varchar(200) NOT NULL,
  `city` varchar(100) DEFAULT NULL,
  `address` varchar(255) DEFAULT NULL,
  `phone` varchar(50) DEFAULT NULL,
  `website` varchar(200) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- A tábla adatainak kiíratása `cinemas`
--

INSERT INTO `cinemas` (`id`, `name`, `city`, `address`, `phone`, `website`) VALUES
(1, 'Cinema City Aréna', 'Budapest', 'Kerepesi út 9', '06-1-234-5678', 'https://cinemacity.hu'),
(2, 'Apollo', 'Pécs', 'Perczel Miklós u. 22.', '06-70-286-8447', 'https://www.apollopecs.hu/');

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `discounts`
--

DROP TABLE IF EXISTS `discounts`;
CREATE TABLE `discounts` (
  `id` int(11) NOT NULL,
  `code` varchar(50) NOT NULL,
  `descreption` varchar(255) DEFAULT NULL,
  `discount_type` enum('percent','fixed') NOT NULL,
  `value` decimal(10,2) NOT NULL,
  `valid_from` date DEFAULT NULL,
  `valid_to` date DEFAULT NULL,
  `min_total` decimal(10,2) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- A tábla adatainak kiíratása `discounts`
--

INSERT INTO `discounts` (`id`, `code`, `descreption`, `discount_type`, `value`, `valid_from`, `valid_to`, `min_total`, `is_active`, `created`) VALUES
(1, 'STUDENT', '10% discount for students', 'percent', '10.00', '2025-01-01', '2025-12-31', '0.00', 1, '2025-12-09 10:10:17'),
(2, 'SENIOR', '15% discount for people over 65 years old', 'percent', '15.00', '2025-01-01', '2026-01-01', '0.00', 1, '2025-12-09 10:10:17'),
(3, 'EXPIRED1', 'Expired coupon for testing only', 'percent', '10.00', '2024-01-01', '2024-01-01', '0.00', 0, '2025-12-09 10:10:17');

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `events`
--

DROP TABLE IF EXISTS `events`;
CREATE TABLE `events` (
  `id` int(11) NOT NULL,
  `title` varchar(200) NOT NULL,
  `room` varchar(200) NOT NULL,
  `type` varchar(20) NOT NULL,
  `start` datetime NOT NULL,
  `end` datetime NOT NULL,
  `seats` int(11) NOT NULL,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `cinema_id` int(11) DEFAULT NULL,
  `theatre_id` int(11) DEFAULT NULL,
  `total_tickets` int(11) DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- A tábla adatainak kiíratása `events`
--

INSERT INTO `events` (`id`, `title`, `room`, `type`, `start`, `end`, `seats`, `created`, `cinema_id`, `theatre_id`, `total_tickets`) VALUES
(7, 'Avatar 3', '4', 'cinema', '2025-10-10 18:00:00', '2025-10-10 20:30:00', 250, '2025-11-25 19:15:52', 1, NULL, 2),
(8, 'Az operaház fantomja', '7', 'theatre', '2025-10-12 19:00:00', '2025-10-12 22:00:00', 900, '2025-11-25 19:15:52', NULL, 1, 5),
(9, 'Jurassic World', '9', 'cinema', '2025-10-17 20:00:00', '2025-10-12 22:30:00', 400, '2025-11-25 19:15:52', 1, NULL, 5),
(10, 'Joker', '2', 'cinema', '2026-02-26 00:00:00', '2026-03-03 00:00:00', 15, '2026-02-26 12:43:07', NULL, NULL, 0),
(11, 'Hamilton', '10', 'theatre', '2026-03-10 00:00:00', '2026-03-25 00:00:00', 400, '2026-02-26 12:45:02', NULL, NULL, 0);

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `favorites`
--

DROP TABLE IF EXISTS `favorites`;
CREATE TABLE `favorites` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `event_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `movie_info`
--

DROP TABLE IF EXISTS `movie_info`;
CREATE TABLE `movie_info` (
  `event_id` int(11) NOT NULL,
  `genre` varchar(100) NOT NULL,
  `writer` varchar(120) NOT NULL,
  `length_min` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- A tábla adatainak kiíratása `movie_info`
--

INSERT INTO `movie_info` (`event_id`, `genre`, `writer`, `length_min`) VALUES
(7, 'Action / Adventure', 'James Cameron', 162),
(9, 'Adventure / Sci-Fi', 'Michael Crichton', 124),
(10, 'Drama / Crime', 'Todd Phillips', 122);

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `orders`
--

DROP TABLE IF EXISTS `orders`;
CREATE TABLE `orders` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `total` decimal(10,2) NOT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'pending',
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `title` varchar(200) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `payments`
--

DROP TABLE IF EXISTS `payments`;
CREATE TABLE `payments` (
  `id` int(11) NOT NULL,
  `order_id` int(11) NOT NULL,
  `provider` varchar(50) NOT NULL,
  `transaction_ref` varchar(100) DEFAULT NULL,
  `amount` decimal(10,2) NOT NULL,
  `status` varchar(20) NOT NULL,
  `paid_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `reviews`
--

DROP TABLE IF EXISTS `reviews`;
CREATE TABLE `reviews` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `event_id` int(11) NOT NULL,
  `rating` tinyint(4) NOT NULL,
  `comment` text,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `seat_map`
--

DROP TABLE IF EXISTS `seat_map`;
CREATE TABLE `seat_map` (
  `id` int(11) NOT NULL,
  `event_id` int(11) NOT NULL,
  `row_label` varchar(10) NOT NULL,
  `seat_number` int(11) NOT NULL,
  `seat_label` varchar(20) NOT NULL,
  `seat_type` enum('Normal','VIP','Premium') NOT NULL DEFAULT 'Normal'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- A tábla adatainak kiíratása `seat_map`
--

INSERT INTO `seat_map` (`id`, `event_id`, `row_label`, `seat_number`, `seat_label`, `seat_type`) VALUES
(4, 7, 'A', 1, 'A1', 'VIP'),
(5, 8, 'B', 1, 'B1', 'Normal'),
(6, 9, 'C', 1, 'C1', 'Premium');

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `theatre`
--

DROP TABLE IF EXISTS `theatre`;
CREATE TABLE `theatre` (
  `id` int(11) NOT NULL,
  `name` varchar(200) NOT NULL,
  `city` varchar(100) DEFAULT NULL,
  `address` varchar(255) DEFAULT NULL,
  `phone` varchar(50) DEFAULT NULL,
  `website` varchar(200) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- A tábla adatainak kiíratása `theatre`
--

INSERT INTO `theatre` (`id`, `name`, `city`, `address`, `phone`, `website`) VALUES
(1, 'Vígszínház', 'Budapest', 'Szent István krt. 14.', '06-1-332-0888', 'https://vigszinhaz.hu'),
(2, 'Theatre Mohács', 'Mohács', 'Deák tér 6.', '06-30-010-8101', 'https://kossuthteatrum.hu/');

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `tickets`
--

DROP TABLE IF EXISTS `tickets`;
CREATE TABLE `tickets` (
  `id` int(11) NOT NULL,
  `event_id` int(11) NOT NULL,
  `seat_label` varchar(50) DEFAULT NULL,
  `price` decimal(10,2) NOT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'available',
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- A tábla adatainak kiíratása `tickets`
--

INSERT INTO `tickets` (`id`, `event_id`, `seat_label`, `price`, `status`, `created`) VALUES
(1, 7, 'A20', '2990.00', 'paid', '2025-11-28 09:59:50'),
(6, 8, 'B15', '2990.00', 'available', '2025-11-28 10:20:04'),
(9, 7, 'B20', '2990.00', 'paid', '2025-12-09 10:25:40'),
(10, 8, 'A30', '2990.00', 'paid', '2025-12-09 10:25:40'),
(11, 9, 'A1', '2990.00', 'available', '2026-02-24 08:39:11'),
(12, 9, 'A2', '2990.00', 'available', '2026-02-24 08:39:11'),
(13, 9, 'A3', '2990.00', 'available', '2026-02-24 08:39:11'),
(14, 9, 'B1', '2990.00', 'available', '2026-02-24 08:39:11'),
(15, 9, 'B2', '2990.00', 'available', '2026-02-24 08:39:11'),
(16, 8, 'P1', '4990.00', 'available', '2026-02-24 08:51:40'),
(17, 8, 'P2', '4990.00', 'available', '2026-02-24 08:51:40'),
(18, 8, 'P3', '4990.00', 'available', '2026-02-24 08:51:40');

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `users`
--

DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `id` int(11) NOT NULL,
  `email` varchar(190) NOT NULL,
  `password` varchar(255) NOT NULL,
  `name` varchar(120) NOT NULL,
  `role` enum('admin','user') NOT NULL DEFAULT 'user',
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `card_last4` varchar(4) DEFAULT NULL,
  `card_type` varchar(20) DEFAULT NULL,
  `card_exp_month` int(11) DEFAULT NULL,
  `card_exp_year` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- A tábla adatainak kiíratása `users`
--

INSERT INTO `users` (`id`, `email`, `password`, `name`, `role`, `created`, `card_last4`, `card_type`, `card_exp_month`, `card_exp_year`) VALUES
(3, 'user@test.com', 'password_hash', 'UserTest', 'user', '2026-02-23 16:23:33', NULL, NULL, NULL, NULL),
(4, 'kissjozsi@test.com', 'jozsi123', 'Kiss József', 'user', '2026-02-24 12:08:09', NULL, NULL, NULL, NULL),
(6, 'admin1@gmail.com', 'a1', 'Admin1', 'admin', '2026-02-24 12:24:37', NULL, NULL, NULL, NULL),
(7, 'admin2@gmail.com', 'a2', 'Admin2', 'admin', '2026-02-24 12:25:08', NULL, NULL, NULL, NULL),
(8, 'magdi67@gmail.com', 'magdi67', 'Nagy Magdolna', 'user', '2026-02-25 16:31:45', NULL, NULL, NULL, NULL),
(9, 'admin3@gmail.com', 'a3', 'Admin3', 'admin', '2026-02-26 09:32:50', NULL, NULL, NULL, NULL);

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `user_activity_log`
--

DROP TABLE IF EXISTS `user_activity_log`;
CREATE TABLE `user_activity_log` (
  `id` int(11) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `action` varchar(100) NOT NULL,
  `description` text,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- A tábla adatainak kiíratása `user_activity_log`
--

INSERT INTO `user_activity_log` (`id`, `user_id`, `action`, `description`, `created`) VALUES
(1, NULL, 'REGISTER', 'User registered with email user@test.com.', '2025-12-12 11:22:35'),
(2, NULL, 'LOGIN', 'User logged in successfully.', '2025-12-12 11:22:35'),
(3, NULL, 'ADD_FAVORITE', 'User added an event to favorites.', '2025-12-12 11:22:35'),
(4, NULL, 'LOGOUT', 'User logged out.', '2025-12-12 11:22:35'),
(5, NULL, 'APPLY_DISCOUNT', 'User applied discount code STUDENT10.', '2025-12-12 11:22:35');

--
-- Indexek a kiírt táblákhoz
--

--
-- A tábla indexei `admins`
--
ALTER TABLE `admins`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `user_id` (`user_id`);

--
-- A tábla indexei `bought_tickets`
--
ALTER TABLE `bought_tickets`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uniq_ticket_once` (`ticket_id`),
  ADD KEY `idx_order` (`order_id`);

--
-- A tábla indexei `cinemas`
--
ALTER TABLE `cinemas`
  ADD PRIMARY KEY (`id`);

--
-- A tábla indexei `discounts`
--
ALTER TABLE `discounts`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `code` (`code`),
  ADD KEY `idx_discounts_active` (`is_active`),
  ADD KEY `idx_discounts_valid` (`valid_from`,`valid_to`);

--
-- A tábla indexei `events`
--
ALTER TABLE `events`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_start` (`start`),
  ADD KEY `idx_type` (`type`),
  ADD KEY `fk_events_cinema` (`cinema_id`),
  ADD KEY `fk_events_theatre` (`theatre_id`);

--
-- A tábla indexei `favorites`
--
ALTER TABLE `favorites`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uniq_user_event_fav` (`user_id`,`event_id`),
  ADD KEY `idx_fav_user` (`user_id`),
  ADD KEY `idx_fav_event` (`event_id`);

--
-- A tábla indexei `movie_info`
--
ALTER TABLE `movie_info`
  ADD PRIMARY KEY (`event_id`);

--
-- A tábla indexei `orders`
--
ALTER TABLE `orders`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_user` (`user_id`),
  ADD KEY `idx_status` (`status`);

--
-- A tábla indexei `payments`
--
ALTER TABLE `payments`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_payments_order` (`order_id`),
  ADD KEY `idx_payments_status` (`status`);

--
-- A tábla indexei `reviews`
--
ALTER TABLE `reviews`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uniq_user_event_review` (`user_id`,`event_id`),
  ADD KEY `idx_reviews_event` (`event_id`),
  ADD KEY `idx_reviews_user` (`user_id`);

--
-- A tábla indexei `seat_map`
--
ALTER TABLE `seat_map`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uniq_event_seat` (`event_id`,`seat_label`),
  ADD KEY `idx_seatmap_event` (`event_id`),
  ADD KEY `idx_seatmap_type` (`seat_type`);

--
-- A tábla indexei `theatre`
--
ALTER TABLE `theatre`
  ADD PRIMARY KEY (`id`);

--
-- A tábla indexei `tickets`
--
ALTER TABLE `tickets`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_event` (`event_id`),
  ADD KEY `idx_status` (`status`);

--
-- A tábla indexei `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email` (`email`);

--
-- A tábla indexei `user_activity_log`
--
ALTER TABLE `user_activity_log`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_log_user` (`user_id`),
  ADD KEY `idx_log_action` (`action`);

--
-- A kiírt táblák AUTO_INCREMENT értéke
--

--
-- AUTO_INCREMENT a táblához `admins`
--
ALTER TABLE `admins`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT a táblához `bought_tickets`
--
ALTER TABLE `bought_tickets`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT a táblához `cinemas`
--
ALTER TABLE `cinemas`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT a táblához `discounts`
--
ALTER TABLE `discounts`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT a táblához `events`
--
ALTER TABLE `events`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=12;

--
-- AUTO_INCREMENT a táblához `favorites`
--
ALTER TABLE `favorites`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT a táblához `orders`
--
ALTER TABLE `orders`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT a táblához `payments`
--
ALTER TABLE `payments`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT a táblához `reviews`
--
ALTER TABLE `reviews`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT a táblához `seat_map`
--
ALTER TABLE `seat_map`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT a táblához `theatre`
--
ALTER TABLE `theatre`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT a táblához `tickets`
--
ALTER TABLE `tickets`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=19;

--
-- AUTO_INCREMENT a táblához `users`
--
ALTER TABLE `users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT a táblához `user_activity_log`
--
ALTER TABLE `user_activity_log`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- Megkötések a kiírt táblákhoz
--

--
-- Megkötések a táblához `admins`
--
ALTER TABLE `admins`
  ADD CONSTRAINT `fk_admins_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Megkötések a táblához `bought_tickets`
--
ALTER TABLE `bought_tickets`
  ADD CONSTRAINT `fk_items_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_items_ticket` FOREIGN KEY (`ticket_id`) REFERENCES `tickets` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Megkötések a táblához `events`
--
ALTER TABLE `events`
  ADD CONSTRAINT `fk_events_cinema` FOREIGN KEY (`cinema_id`) REFERENCES `cinemas` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_events_theatre` FOREIGN KEY (`theatre_id`) REFERENCES `theatre` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Megkötések a táblához `favorites`
--
ALTER TABLE `favorites`
  ADD CONSTRAINT `fk_fav_event` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_fav_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Megkötések a táblához `movie_info`
--
ALTER TABLE `movie_info`
  ADD CONSTRAINT `fk_movieinfo_event` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE;

--
-- Megkötések a táblához `orders`
--
ALTER TABLE `orders`
  ADD CONSTRAINT `fk_orders_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Megkötések a táblához `payments`
--
ALTER TABLE `payments`
  ADD CONSTRAINT `fk_payments_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Megkötések a táblához `reviews`
--
ALTER TABLE `reviews`
  ADD CONSTRAINT `fk_reviews_event` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_reviews_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Megkötések a táblához `seat_map`
--
ALTER TABLE `seat_map`
  ADD CONSTRAINT `fk_seatmap_event` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Megkötések a táblához `tickets`
--
ALTER TABLE `tickets`
  ADD CONSTRAINT `fk_tickets_event` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Megkötések a táblához `user_activity_log`
--
ALTER TABLE `user_activity_log`
  ADD CONSTRAINT `fk_log_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
