-- phpMyAdmin SQL Dump
-- version 5.1.2
-- https://www.phpmyadmin.net/
--
-- Gép: localhost:3306
-- Létrehozás ideje: 2026. Ápr 22. 14:45
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

DELIMITER $$
--
-- Eljárások
--
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

CREATE DEFINER=`root`@`localhost` PROCEDURE `cancel_reservation` (IN `p_ticket_id` INT)   BEGIN

UPDATE tickets SET status = 'available' WHERE id = p_ticket_id AND status = 'reserved';

END$$

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

CREATE DEFINER=`root`@`localhost` PROCEDURE `create_cinema` (IN `p_name` VARCHAR(200), IN `p_city` VARCHAR(100), IN `p_address` VARCHAR(255), IN `p_phone` VARCHAR(50), IN `p_website` VARCHAR(200))   BEGIN

INSERT INTO cinemas (name, city, address, phone, website)
VALUES (p_name, p_city, p_address, p_phone, p_website);

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `create_discount` (IN `p_code` VARCHAR(50), IN `p_description` VARCHAR(255), IN `p_discount_type` ENUM('percent','fixed'), IN `p_value` DECIMAL(10,2), IN `p_valid_from` DATE, IN `p_valid_to` DATE, IN `p_min_total` DECIMAL(10,2))   BEGIN

INSERT INTO discounts (code, description, discount_type, value, valid_from, valid_to, min_total, is_active )
VALUES (p_code, p_description, p_discount_type, p_value, p_valid_from, p_valid_to, p_min_total, 1);

END$$

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

CREATE DEFINER=`root`@`localhost` PROCEDURE `create_theatre` (IN `p_name` VARCHAR(200), IN `p_city` VARCHAR(100), IN `p_address` VARCHAR(255), IN `p_phone` VARCHAR(50), IN `p_website` VARCHAR(200))   BEGIN

INSERT INTO theatres (name, city, address, phone, website)
VALUES (p_name, p_city, p_address, p_phone, p_website);

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_active_discount_by_code` (IN `p_code` VARCHAR(50))   BEGIN

SELECT id, code, description, discount_type, value, valid_from, valid_to, min_total, is_active, created FROM discounts WHERE code = p_code AND is_active = 1 AND (valid_from IS NULL OR valid_from <= CURDATE()) AND (valid_to IS NULL OR valid_to >= CURDATE());

END$$

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

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_cinema_events` (IN `p_cinema_id` INT)   BEGIN

SELECT e.id AS event_id, e.title, e.room, e.start, e.end, e.seats FROM events e WHERE e.cinema_id = p_cinema_id ORDER BY e.start;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_event_full_data` (IN `p_event_id` INT)   BEGIN

SELECT e.id, e.title, e.room, e.type, e.start, e.end, e.seats,
SUM(CASE WHEN t.status = 'available' THEN 1 ELSE 0 END) AS available_tickets,
SUM(CASE WHEN t.status = 'reserved' THEN 1 ELSE 0 END) AS reserved_tickets,
SUM(CASE WHEN t.status = 'sold' THEN 1 ELSE 0 END) AS sold_tickets FROM events e 

LEFT JOIN tickets t ON t.event_id = e.id WHERE e.id = p_event_id;


END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_event_revenue` (IN `p_event_id` INT)   BEGIN

SELECT e.title AS event_title, COUNT(bt.id) AS sold_tickets_count, IFNULL(SUM(bt.price),0) AS total_revenue FROM events e 
LEFT JOIN tickets t ON t.event_id = e.id
LEFT JOIN bought_tickets bt ON bt.ticket_id = t.id WHERE e.id = p_event_id;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_favorites_for_user` (IN `p_user_id` INT)   BEGIN

SELECT f.id AS favorite_id,  e.id AS event_id, e.title, e.type, e.start, e.end, e.room, f.created AS favorited_at FROM favorites f JOIN events e ON e.id = f.event_id WHERE f.user_id = p_user_id ORDER BY e.start;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_theatre_events` (IN `p_theatre_id` INT)   BEGIN

SELECT e.id AS event_id, e.title, e.room, e.start, e.end, e.seats FROM events e WHERE e.theatre_id = p_theatre_id ORDER BY e.start;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_user_orders` (IN `p_user_email` VARCHAR(190))   BEGIN

SELECT  o.id AS order_id, o.total, o.status, o.created FROM orders o JOIN users u ON u.id = o.user_id WHERE u.email = p_user_email ORDER BY o.created DESC;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `list_tickets_for_event` (IN `p_event_id` INT)   BEGIN 
	SELECT t.id AS ticket_id, t.seat_label, t.price, t.status
     FROM tickets t WHERE t.event_id = p_event_id
		ORDER BY t.seat_label;
      
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `mark_ticket_as_sold` (IN `p_ticket_id` INT)   BEGIN

UPDATE tickets SET status = 'sold' WHERE id = p_ticket_id AND status IN ('reserved', 'available');


END$$

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

CREATE DEFINER=`root`@`localhost` PROCEDURE `reserve_ticket` (IN `p_ticket_id` INT)   BEGIN

UPDATE tickets SET status = 'reserved' WHERE id = p_ticket_id AND status = 'available';


END$$

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

CREATE TABLE `bought_tickets` (
  `id` int(11) NOT NULL,
  `order_id` int(11) NOT NULL,
  `ticket_id` int(11) NOT NULL,
  `price` decimal(10,2) NOT NULL,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- A tábla adatainak kiíratása `bought_tickets`
--

INSERT INTO `bought_tickets` (`id`, `order_id`, `ticket_id`, `price`, `created`) VALUES
(1, 1, 12, '2990.00', '2026-04-21 15:15:40'),
(2, 2, 211, '4990.00', '2026-04-22 10:39:25'),
(3, 2, 212, '4990.00', '2026-04-22 10:39:25'),
(4, 2, 213, '4990.00', '2026-04-22 10:39:25'),
(5, 3, 191, '4990.00', '2026-04-22 10:39:58'),
(6, 3, 192, '4990.00', '2026-04-22 10:39:58'),
(7, 3, 193, '4990.00', '2026-04-22 10:39:58');

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `cinemas`
--

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
(11, 'Hamilton', '10', 'theatre', '2026-03-10 00:00:00', '2026-03-25 00:00:00', 400, '2026-02-26 12:45:02', NULL, NULL, 0),
(12, 'Joker', '2', 'cinema', '2026-05-02 18:00:00', '2026-05-02 20:10:00', 32, '2026-04-22 10:32:21', 1, NULL, 32),
(13, 'Joker', '2', 'cinema', '2026-05-03 20:30:00', '2026-05-03 22:40:00', 32, '2026-04-22 10:32:21', 1, NULL, 32),
(14, 'Avatar 3', '4', 'cinema', '2026-05-04 17:30:00', '2026-05-04 20:00:00', 32, '2026-04-22 10:32:21', 1, NULL, 32),
(15, 'Avatar 3', '4', 'cinema', '2026-05-06 19:00:00', '2026-05-06 21:30:00', 32, '2026-04-22 10:32:21', 1, NULL, 32),
(16, 'Az operaház fantomja', '7', 'theatre', '2026-05-02 15:00:00', '2026-05-02 18:00:00', 32, '2026-04-22 10:32:21', NULL, 1, 32),
(17, 'Az operaház fantomja', '7', 'theatre', '2026-05-03 19:00:00', '2026-05-03 22:00:00', 32, '2026-04-22 10:32:21', NULL, 1, 32),
(18, 'Az operaház fantomja', '7', 'theatre', '2026-05-04 19:00:00', '2026-05-04 22:00:00', 32, '2026-04-22 10:32:21', NULL, 1, 32),
(19, 'Hamilton', '10', 'theatre', '2026-05-06 18:00:00', '2026-05-06 21:00:00', 32, '2026-04-22 10:32:21', NULL, 1, 32),
(20, 'Hamilton', '10', 'theatre', '2026-05-08 19:30:00', '2026-05-08 22:30:00', 32, '2026-04-22 10:32:21', NULL, 1, 32);

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `favorites`
--

CREATE TABLE `favorites` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `event_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `movie_info`
--

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

CREATE TABLE `orders` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `total` decimal(10,2) NOT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'pending',
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `title` varchar(200) NOT NULL,
  `customer_name` varchar(120) DEFAULT NULL,
  `customer_phone` varchar(50) DEFAULT NULL,
  `customer_email` varchar(190) DEFAULT NULL,
  `payment_method` varchar(30) DEFAULT NULL,
  `reservation_code` varchar(40) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- A tábla adatainak kiíratása `orders`
--

INSERT INTO `orders` (`id`, `user_id`, `total`, `status`, `created`, `title`, `customer_name`, `customer_phone`, `customer_email`, `payment_method`, `reservation_code`) VALUES
(1, 4, '2990.00', 'paid', '2026-04-21 15:15:40', 'Online order - A2', NULL, NULL, NULL, NULL, NULL),
(2, 4, '14970.00', 'reserved', '2026-04-22 10:39:25', 'Az operaház fantomja', 'Kiss József', '33324140', 'kissjozsi@test.com', 'onsite', '6854365627'),
(3, 4, '14970.00', 'reserved', '2026-04-22 10:39:58', 'Az operaház fantomja', 'Kiss József', '33324140', 'kissjozsi@test.com', 'onsite', '6854398464');

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `payments`
--

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

CREATE TABLE `tickets` (
  `id` int(11) NOT NULL,
  `event_id` int(11) NOT NULL,
  `seat_label` varchar(50) DEFAULT NULL,
  `price` decimal(10,2) NOT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'available',
  `reserved_by_user_id` int(11) DEFAULT NULL,
  `reserved_until` datetime DEFAULT NULL,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- A tábla adatainak kiíratása `tickets`
--

INSERT INTO `tickets` (`id`, `event_id`, `seat_label`, `price`, `status`, `reserved_by_user_id`, `reserved_until`, `created`) VALUES
(1, 7, 'A20', '2990.00', 'sold', NULL, NULL, '2025-11-28 09:59:50'),
(6, 8, 'B15', '2990.00', 'available', NULL, NULL, '2025-11-28 10:20:04'),
(9, 7, 'B20', '2990.00', 'sold', NULL, NULL, '2025-12-09 10:25:40'),
(10, 8, 'A30', '2990.00', 'sold', NULL, NULL, '2025-12-09 10:25:40'),
(11, 9, 'A1', '2990.00', 'available', NULL, NULL, '2026-02-24 08:39:11'),
(12, 9, 'A2', '2990.00', 'sold', NULL, NULL, '2026-02-24 08:39:11'),
(13, 9, 'A3', '2990.00', 'available', NULL, NULL, '2026-02-24 08:39:11'),
(14, 9, 'B1', '2990.00', 'available', NULL, NULL, '2026-02-24 08:39:11'),
(15, 9, 'B2', '2990.00', 'available', NULL, NULL, '2026-02-24 08:39:11'),
(16, 8, 'P1', '4990.00', 'available', NULL, NULL, '2026-02-24 08:51:40'),
(17, 8, 'P2', '4990.00', 'available', NULL, NULL, '2026-02-24 08:51:40'),
(18, 8, 'P3', '4990.00', 'available', NULL, NULL, '2026-02-24 08:51:40'),
(19, 12, 'A1', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(20, 12, 'A2', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(21, 12, 'A3', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(22, 12, 'A4', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(23, 12, 'A5', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(24, 12, 'A6', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(25, 12, 'A7', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(26, 12, 'A8', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(27, 12, 'B1', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(28, 12, 'B2', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(29, 12, 'B3', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(30, 12, 'B4', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(31, 12, 'B5', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(32, 12, 'B6', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(33, 12, 'B7', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(34, 12, 'B8', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(35, 12, 'C1', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(36, 12, 'C2', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(37, 12, 'C3', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(38, 12, 'C4', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(39, 12, 'C5', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(40, 12, 'C6', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(41, 12, 'C7', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(42, 12, 'C8', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(43, 12, 'D1', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(44, 12, 'D2', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(45, 12, 'D3', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(46, 12, 'D4', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(47, 12, 'D5', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(48, 12, 'D6', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(49, 12, 'D7', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(50, 12, 'D8', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(51, 13, 'A1', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(52, 13, 'A2', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(53, 13, 'A3', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(54, 13, 'A4', '2990.00', 'sold', NULL, NULL, '2026-04-22 10:32:21'),
(55, 13, 'A5', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(56, 13, 'A6', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(57, 13, 'A7', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(58, 13, 'A8', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(59, 13, 'B1', '2990.00', 'reserved', NULL, NULL, '2026-04-22 10:32:21'),
(60, 13, 'B2', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(61, 13, 'B3', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(62, 13, 'B4', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(63, 13, 'B5', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(64, 13, 'B6', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(65, 13, 'B7', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(66, 13, 'B8', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(67, 13, 'C1', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(68, 13, 'C2', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(69, 13, 'C3', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(70, 13, 'C4', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(71, 13, 'C5', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(72, 13, 'C6', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(73, 13, 'C7', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(74, 13, 'C8', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(75, 13, 'D1', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(76, 13, 'D2', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(77, 13, 'D3', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(78, 13, 'D4', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(79, 13, 'D5', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(80, 13, 'D6', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(81, 13, 'D7', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(82, 13, 'D8', '2990.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(83, 14, 'A1', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(84, 14, 'A2', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(85, 14, 'A3', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(86, 14, 'A4', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(87, 14, 'A5', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(88, 14, 'A6', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(89, 14, 'A7', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(90, 14, 'A8', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(91, 14, 'B1', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(92, 14, 'B2', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(93, 14, 'B3', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(94, 14, 'B4', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(95, 14, 'B5', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(96, 14, 'B6', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(97, 14, 'B7', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(98, 14, 'B8', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(99, 14, 'C1', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(100, 14, 'C2', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(101, 14, 'C3', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(102, 14, 'C4', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(103, 14, 'C5', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(104, 14, 'C6', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(105, 14, 'C7', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(106, 14, 'C8', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(107, 14, 'D1', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(108, 14, 'D2', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(109, 14, 'D3', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(110, 14, 'D4', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(111, 14, 'D5', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(112, 14, 'D6', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(113, 14, 'D7', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(114, 14, 'D8', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(115, 15, 'A1', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(116, 15, 'A2', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(117, 15, 'A3', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(118, 15, 'A4', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(119, 15, 'A5', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(120, 15, 'A6', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(121, 15, 'A7', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(122, 15, 'A8', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(123, 15, 'B1', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(124, 15, 'B2', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(125, 15, 'B3', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(126, 15, 'B4', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(127, 15, 'B5', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(128, 15, 'B6', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(129, 15, 'B7', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(130, 15, 'B8', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(131, 15, 'C1', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(132, 15, 'C2', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(133, 15, 'C3', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(134, 15, 'C4', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(135, 15, 'C5', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(136, 15, 'C6', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(137, 15, 'C7', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(138, 15, 'C8', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(139, 15, 'D1', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(140, 15, 'D2', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(141, 15, 'D3', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(142, 15, 'D4', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(143, 15, 'D5', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(144, 15, 'D6', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(145, 15, 'D7', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(146, 15, 'D8', '3490.00', 'available', NULL, NULL, '2026-04-22 10:32:21'),
(147, 16, 'A1', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(148, 16, 'A2', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(149, 16, 'A3', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(150, 16, 'A4', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(151, 16, 'A5', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(152, 16, 'A6', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(153, 16, 'A7', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(154, 16, 'A8', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(155, 16, 'B1', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(156, 16, 'B2', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(157, 16, 'B3', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(158, 16, 'B4', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(159, 16, 'B5', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(160, 16, 'B6', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(161, 16, 'B7', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(162, 16, 'B8', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(163, 16, 'C1', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(164, 16, 'C2', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(165, 16, 'C3', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(166, 16, 'C4', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(167, 16, 'C5', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(168, 16, 'C6', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(169, 16, 'C7', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(170, 16, 'C8', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(171, 16, 'D1', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(172, 16, 'D2', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(173, 16, 'D3', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(174, 16, 'D4', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(175, 16, 'D5', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(176, 16, 'D6', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(177, 16, 'D7', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(178, 16, 'D8', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(179, 17, 'A1', '4990.00', 'reserved', NULL, NULL, '2026-04-22 10:32:22'),
(180, 17, 'A2', '4990.00', 'sold', NULL, NULL, '2026-04-22 10:32:22'),
(181, 17, 'A3', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(182, 17, 'A4', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(183, 17, 'A5', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(184, 17, 'A6', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(185, 17, 'A7', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(186, 17, 'A8', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(187, 17, 'B1', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(188, 17, 'B2', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(189, 17, 'B3', '4990.00', 'reserved', NULL, NULL, '2026-04-22 10:32:22'),
(190, 17, 'B4', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(191, 17, 'B5', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(192, 17, 'B6', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(193, 17, 'B7', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(194, 17, 'B8', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(195, 17, 'C1', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(196, 17, 'C2', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(197, 17, 'C3', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(198, 17, 'C4', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(199, 17, 'C5', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(200, 17, 'C6', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(201, 17, 'C7', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(202, 17, 'C8', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(203, 17, 'D1', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(204, 17, 'D2', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(205, 17, 'D3', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(206, 17, 'D4', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(207, 17, 'D5', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(208, 17, 'D6', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(209, 17, 'D7', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(210, 17, 'D8', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(211, 18, 'A1', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(212, 18, 'A2', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(213, 18, 'A3', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(214, 18, 'A4', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(215, 18, 'A5', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(216, 18, 'A6', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(217, 18, 'A7', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(218, 18, 'A8', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(219, 18, 'B1', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(220, 18, 'B2', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(221, 18, 'B3', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(222, 18, 'B4', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(223, 18, 'B5', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(224, 18, 'B6', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(225, 18, 'B7', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(226, 18, 'B8', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(227, 18, 'C1', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(228, 18, 'C2', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(229, 18, 'C3', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(230, 18, 'C4', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(231, 18, 'C5', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(232, 18, 'C6', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(233, 18, 'C7', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(234, 18, 'C8', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(235, 18, 'D1', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(236, 18, 'D2', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(237, 18, 'D3', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(238, 18, 'D4', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(239, 18, 'D5', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(240, 18, 'D6', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(241, 18, 'D7', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(242, 18, 'D8', '4990.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(243, 19, 'A1', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(244, 19, 'A2', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(245, 19, 'A3', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(246, 19, 'A4', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(247, 19, 'A5', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(248, 19, 'A6', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(249, 19, 'A7', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(250, 19, 'A8', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(251, 19, 'B1', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(252, 19, 'B2', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(253, 19, 'B3', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(254, 19, 'B4', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(255, 19, 'B5', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(256, 19, 'B6', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(257, 19, 'B7', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(258, 19, 'B8', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(259, 19, 'C1', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(260, 19, 'C2', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(261, 19, 'C3', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(262, 19, 'C4', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(263, 19, 'C5', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(264, 19, 'C6', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(265, 19, 'C7', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(266, 19, 'C8', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(267, 19, 'D1', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(268, 19, 'D2', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(269, 19, 'D3', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(270, 19, 'D4', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(271, 19, 'D5', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(272, 19, 'D6', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(273, 19, 'D7', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(274, 19, 'D8', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(275, 20, 'A1', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(276, 20, 'A2', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(277, 20, 'A3', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(278, 20, 'A4', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(279, 20, 'A5', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(280, 20, 'A6', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(281, 20, 'A7', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(282, 20, 'A8', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(283, 20, 'B1', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(284, 20, 'B2', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(285, 20, 'B3', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(286, 20, 'B4', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(287, 20, 'B5', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(288, 20, 'B6', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(289, 20, 'B7', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(290, 20, 'B8', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(291, 20, 'C1', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(292, 20, 'C2', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(293, 20, 'C3', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(294, 20, 'C4', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(295, 20, 'C5', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(296, 20, 'C6', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(297, 20, 'C7', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(298, 20, 'C8', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(299, 20, 'D1', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(300, 20, 'D2', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(301, 20, 'D3', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(302, 20, 'D4', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(303, 20, 'D5', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(304, 20, 'D6', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(305, 20, 'D7', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22'),
(306, 20, 'D8', '4590.00', 'available', NULL, NULL, '2026-04-22 10:32:22');

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `users`
--

CREATE TABLE `users` (
  `id` int(11) NOT NULL,
  `email` varchar(190) NOT NULL,
  `password` varchar(255) NOT NULL,
  `name` varchar(120) NOT NULL,
  `username` varchar(100) DEFAULT NULL,
  `phone` varchar(50) DEFAULT NULL,
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

INSERT INTO `users` (`id`, `email`, `password`, `name`, `username`, `phone`, `role`, `created`, `card_last4`, `card_type`, `card_exp_month`, `card_exp_year`) VALUES
(3, 'user@test.com', 'password_hash', 'UserTest', 'user', NULL, 'user', '2026-02-23 16:23:33', NULL, NULL, NULL, NULL),
(4, 'kissjozsi@test.com', 'jozsi123', 'Kiss József', 'kissjozsi', '', 'user', '2026-02-24 12:08:09', NULL, NULL, NULL, NULL),
(6, 'admin1@gmail.com', 'a1', 'Admin1', 'admin1', NULL, 'admin', '2026-02-24 12:24:37', NULL, NULL, NULL, NULL),
(7, 'admin2@gmail.com', 'a2', 'Admin2', 'admin2', NULL, 'admin', '2026-02-24 12:25:08', NULL, NULL, NULL, NULL),
(8, 'magdi67@gmail.com', 'magdi67', 'Nagy Magdolna', 'magdi67', NULL, 'user', '2026-02-25 16:31:45', NULL, NULL, NULL, NULL),
(9, 'admin3@gmail.com', 'a3', 'Admin3', 'admin3', NULL, 'admin', '2026-02-26 09:32:50', NULL, NULL, NULL, NULL);

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `user_activity_log`
--

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
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_orders_reservation_code` (`reservation_code`);

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
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_tickets_reserved_state` (`status`,`reserved_until`,`reserved_by_user_id`),
  ADD KEY `fk_tickets_reserved_by_user` (`reserved_by_user_id`);

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
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

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
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT a táblához `favorites`
--
ALTER TABLE `favorites`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT a táblához `orders`
--
ALTER TABLE `orders`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

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
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=307;

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
  ADD CONSTRAINT `fk_tickets_event` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_tickets_reserved_by_user` FOREIGN KEY (`reserved_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Megkötések a táblához `user_activity_log`
--
ALTER TABLE `user_activity_log`
  ADD CONSTRAINT `fk_log_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
