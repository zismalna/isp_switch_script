# Script to monitor ISP gateway and change default routes

Sensitive data is hidden. Set $company variable, and change "test@example.com" to proper email.

Usage:

Use with cron or install provided unit file.

*systemctl start ispmon@sana.service* or *systemctl start ispmon@s.service* starts the unit with default provider "Sana". Works same way for "Tenet". View status and last journal logs with *systemctl status*. User *systemctl enable* to start at boot time. *journalctl -u* provides logs.
