-- Add master notification kill-switch on the Device table.
-- Defaults to true so existing iPhone devices keep getting alerts after the
-- upgrade; the iOS app's master toggle in Settings flips this to false
-- when the user wants to silence all pushes from this server.
ALTER TABLE "Device" ADD COLUMN "notificationsEnabled" BOOLEAN NOT NULL DEFAULT true;
