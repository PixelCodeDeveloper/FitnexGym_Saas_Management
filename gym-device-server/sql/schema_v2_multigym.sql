-- V2 — Multi-gym production mode
-- gym_id ab NULLABLE hai — jab tak SuperOwner device ko explicitly kisi gym
-- se register nahi karta (POST /api/v2/devices/register), device kisi bhi
-- gym ka data sync nahi karega (safe default).

USE gym_device_db;

ALTER TABLE v2_devices MODIFY gym_id VARCHAR(64) NULL;
