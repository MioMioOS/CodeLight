-- Track the last time each device successfully authenticated. The
-- `notifyLinkedIPhones` push filter uses this to drop devices whose JWT
-- has expired but whose APNs token is still valid (otherwise the server
-- keeps pushing to dead installs forever — Bug 3 follow-up).
--
-- Backfill: existing devices get NOW() as a one-time grace period so we
-- don't immediately silence active users on the day of deployment. After
-- that, only devices that re-authenticate within (tokenExpiryDays + 1)
-- will continue receiving alerts.
ALTER TABLE "Device" ADD COLUMN "lastSeenAt" TIMESTAMP(3);
UPDATE "Device" SET "lastSeenAt" = NOW();
