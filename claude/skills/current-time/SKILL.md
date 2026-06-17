---
name: current-time
description: Get the current date, time, and timezone. Use this whenever you need to know what time or date it is right now - for comparing timestamps, checking PR dates, scheduling context, or any time-sensitive reasoning.
user_invocable: true
---

Run the following command using the Bash tool and report the result:

```bash
date "+%Y-%m-%d %I:%M:%S %p %Z (UTC%z)" && echo "TZ: $(readlink /etc/localtime 2>/dev/null || echo $TZ)"
```

Report the current date, time, and timezone naturally in your response. Include the timezone name so it's clear in an international team context. Do not add any extra commentary unless the user asked a question that requires it.
