# Privacy

Macut is a local clipboard history application. It has no accounts, analytics,
telemetry, cloud synchronization, remote AI calls or application network services.

## Data on your Mac

Clipboard content, searchable text, timestamps, inferred source application,
favorites and image thumbnails are saved in your user Application Support
directory, under `Macut`. Original representations are kept separately from the
search index. These files are not encrypted by Macut. Other processes with access
to your user files may be able to read them.

File clips contain references, not backups of the referenced files. The source
application is inferred from the frontmost application when content is captured;
this information can be inaccurate.

A single local image-file reference also gets a cached thumbnail. This requires
reading that referenced file. macOS may ask you to allow access to the file's
location. Macut does not scan other files in that location. If access is denied or
the source is unavailable, the file reference remains usable as far as the target
application permits; an existing cached thumbnail can still be displayed.

Macut skips known concealed and transient pasteboard markers. Some password
managers are excluded by default, and you can exclude more applications or pause
recording. These mechanisms cannot identify every sensitive item: unmarked
passwords, access tokens and personal information can still be saved. Use the
exclusion list and pause control according to your needs.

You can delete individual entries or clear ordinary history. Clearing ordinary
history preserves favorites and does not clear the current system clipboard.
Automatic cleanup respects the configured count, age and content-size limits.
Secure erasure from SSD storage or backups is not guaranteed.

## Permissions

Accessibility permission is optional and used to paste selected content into
another application. Without it, content can still be copied from history and
pasted manually. Macut does not request screen recording, microphone or camera
access. Login startup is optional and disabled by default.

## Website and releases

The project website is a static GitHub Pages site. It uses no analytics, remote
fonts, cookies or third-party JavaScript. GitHub may process ordinary request logs
according to its own policies. Website demo entries and artwork are fictional,
and the demo never reads a visitor's clipboard.

Published source, generated artwork and release packages do not include a user's
clipboard database, preferences, desktop screenshots or runtime logs. Please do
not post sensitive clipboard content when opening a public issue.
