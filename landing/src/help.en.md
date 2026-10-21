# Help (EN)

<!-- Help in English (spec 023, CA-023-17). It mirrors help.es.md section by section, written from the implemented specs (each section says which) and with the texts of app_en.arb. Comments like this one are not published. The release gate reads this whole file: no square brackets or curly braces in the comments. -->

One task at a time, full screen: that is how the app works. Here is how to use each part of it, also with a screen reader (TalkBack), a keyboard or Switch Access.

## The current task and how to complete it

<!-- Fuente: specs 001 (CA-001-06, 12) y 003 (CA-003-01 a 05, 07). -->

The current task is the first one in your list and the only one you see when you open the app: a sticky note at full screen. If it has an attachment (a photo, a PDF or a web page), it shows right there. At the top you have the “Task menu” and at the bottom, “Press to complete”.

To complete it, **press and hold** “Press to complete” for a little over a second (1.2 s): you'll see the button fill up. If you let go earlier, it isn't completed. When it's done, the note tears, “Well done!” appears and you move on to the next one (“Now on to the next one →”); when you complete the last one, you'll see “All done.”

- Completing **deletes the task completely**, with its attachments: there's no history or trash, and it can't be undone.
- If you leave the app in the background for less than 10 minutes, you find it as you left it; if 10 minutes or more go by, you come back to the current task.
- With a screen reader or Switch Access you don't need to press and hold: use the “Complete task” action (see “Using the app with TalkBack”).

## Create a task and choose where it goes

<!-- Fuente: specs 001 (CA-001-02, 04), 002 (CA-002-01 a 07), 006 (CA-006-15) y 007 (CA-007-05). -->

Open the “Task menu” and choose “New task” (it's also in “All tasks” and, as “Create a task”, when you see “All done.”). Write what you need to do (up to 10,000 characters) and press “Continue”. “Cancel” discards what you wrote without asking.

Then we ask “Where does it go?”:

- “On top”: it becomes the current task, the only one you see. The one you had waits behind it.
- “At the end”: it goes last. You won't see it until you finish the ones before it.
- “Keep editing”: you go back to the editor with your text intact.

The first time you open the app, the first-task editor appears on its own and “Save” saves it without asking where it goes, because there's no other task yet.

A task with a photo, a PDF or a web page always goes on top and doesn't ask where.

## Edit a task

<!-- Fuente: specs 005 (CA-005-04 a 08), 006 (CA-006-13), 007 (CA-007-06) y 009 (CA-009-05). -->

Open the “Task menu” and choose “Edit” (in “All tasks”, use the “Edit task” button in the row). Change the text and press “Save changes”: the task keeps its position and its color. “Cancel” discards your changes.

- A task can't be left empty: with no text and no attachment it isn't saved. To remove it, use “Delete”.
- With an attachment, the editor shows it next to “Remove attachment” and an optional text. You can remove it (if some text is left) or replace it with the (+) button; replacing it doesn't move the task.
- On a web task, “Edit” opens “Load URL” with the current address. A task that isn't a web task doesn't turn into one.

## Delete and undo

<!-- Fuente: specs 014 (CA-014-01 a 14, 17), 004 (CA-004-09) y 006 (CA-006-14), con el ADR-0021. -->

To delete the current task, open the “Task menu” and choose “Delete”; in “All tasks”, use “Delete task” in its row. It doesn't ask for confirmation: the task leaves your list right away and a black strip appears at the bottom, “Task deleted”, with the “Undo” button and a bar that empties.

- You have 4 seconds to press “Undo”. If your Android has a longer “Time to take action”, it lasts that long; on Android 8 and 9, with a screen reader or Switch Access on, it lasts 10 seconds. While the screen reader's or the keyboard's focus is on the strip, the time stops.
- “Undo” puts the task back in its place, with its text, its color and its attachment. Only the last deleted task can be undone.
- The deletion becomes final early if you delete or complete another task, go to another screen (the list, the editor or Settings), reorder, or leave the app in the background. Opening the menu doesn't affect it.
- Once it's final, nothing is left: no text, no attachments, no trash.

## All my tasks and reordering

<!-- Fuente: specs 005 (CA-005-03, 12), 006 (CA-006-01 a 16) y 014 (CA-014-02). -->

To see all your pending tasks, open the “Task menu” and choose “All my tasks” (it shows how many there are; with a single task it can't be opened: “This is your only task”). The first row is the current task. “New task” creates another one and “Back to the task” takes you to the main screen.

There are three ways to change the order:

- Drag: put your finger on the handle, at the left of the row, and drag; or press and hold the row for a moment and drag it. The order is saved when you let go. The current task can't be dragged, but you can drop another one on top of it to take its place.
- Without dragging: tap the handle (“Move task”) and choose “Make current”, “Move up” or “Move down” (only the ones that make sense at that position appear).
- With a screen reader or Switch Access: each row has those same options as actions (see “Using the app with TalkBack”).

To edit a task, use “Edit task” or double-tap its row; to delete it, “Delete task”.

## Photos, PDFs and web pages

<!-- Fuente: specs 007 (CA-007-02, 03, 09, 11, 13, 19), 008 (CA-008-03, 09 a 12), 009 (CA-009-01 a 11, 15) y 016 (CA-016-02, 09, 12). -->

When you create or edit a task, the (+) button opens “Add to the task”. You don't need to give permission to the camera, the photos or the files: the app opens the system camera or picker and only receives what you choose.

- “Take photo” opens the system camera.
- “Upload images” opens the system photo picker: choose one or several, up to 10 photos. JPEG, PNG, WebP, GIF and HEIC are accepted (the last one on Android 9 or later), up to 30 MB and 64 megapixels each. The app keeps its own copy without metadata (location, date, camera); your original isn't touched.
- With several photos, the task is a carousel: you see one at a time and swipe one finger sideways to change photo (after the last one comes the first). One dot per photo shows which one you're on. If you choose more than 10, the first 10 are used.
- “Upload file” accepts PDFs only, up to 10 MB and 20 pages: it's meant for quick reference such as tickets, timetables or maps. The app remembers where you were. Links in the PDF ask for confirmation before they open; the PDF's scripts and forms don't work.
- “Load URL” shows a live web page inside the task. **It needs a connection**: without one you'll see “You need a connection to view this page.” and “Try again”. It only loads over a secure connection (`https`); the app keeps only the address and you can't browse from the page (its links do nothing).

With a photo, a PDF or a web page, turn your phone sideways to see the attachment bigger, without the menu or the complete button; turn it back to portrait to use them. If an attachment's file is missing (for example, after restoring a backup), you'll see “Attachment unavailable”.

## Settings

<!-- Fuente: specs 015 (CA-015-01b, 04a a 04c, 05, 08, 09, 12a), 017 (CA-017-01, 06 a 09, 13), 019 (CA-019-03, 08, 10, 15, 19a, 20, 29) y 010 (CA-010-01, 02). -->

Open the “Task menu” and choose “Settings”. There you'll find:

- “Language”: “Same as system” (the starting option: it uses the first language of your phone that the app supports, Spanish or English; if there's none, English), “Español” or “English”. It changes right away, without restarting the app.
- “Notifications” (Android only; they start off): turn them on and choose “Notifications per day”, 1, 2 or 3, at 08:55, 13:55 and 18:55 (your phone's time; they can't be changed). Each one shows your current task; they don't arrive if you have no tasks left or if you're looking at the app, and tapping one opens the app on the current task. Before you turn them on, Settings warns you: “The notification shows your current task. It also shows when your phone is locked, unless you hide sensitive content in your phone's settings.” On Android 13 or later, the system asks for permission when you turn them on; if they're blocked, the row says so and “Open notification settings” takes you to the system settings.
- “Keep screen on” (off by default): with a task with a photo, a PDF or a web page in view, the screen doesn't turn off or lock, with no time limit. With a text-only task it does nothing.
- “Lock zoom” (off by default; photos only): the current task's photo can't be zoomed with a pinch or moved by touch; it stays where it is. Changing photo by swiping, the screen reader's actions and the system magnifier keep working.
- “Privacy policy”, “Third-party licenses” and “Help”, under “Information”, open this website in your browser and need a connection.

## Recents

<!-- Fuente: specs 011 (CA-011-01, 02, 04) y 001 (CA-001-12). -->

The app **doesn't show your tasks in “Recents”** (Android's list of recent apps): not the text, nor the photos, nor the PDFs, nor the web pages, on any of its screens. What shows instead is up to the system.

- Screenshots and screen recordings do include the content: it's only hidden in “Recents”.
- When you return to the app, if 10 minutes or more have passed in the background you see the current task; if not, the same screen as before.

## Backups

<!-- Fuente: specs 007 (CA-007-18) y 019 (CA-019-23), y la sección de copias de seguridad de la política de privacidad. -->

Android can copy apps' data to your Google account and move it to a new phone. In this app:

- Your tasks are copied (text, order and, where they have one, the PDF's name or the web page's address) and so are your settings, only if the backup is end-to-end encrypted, which requires a screen lock (Android 9 or later). On Android 8 nothing is copied.
- The photo and PDF files aren't uploaded to the cloud: when restored, those tasks say “Attachment unavailable” and you can remove the attachment or delete the task.
- When you transfer data straight from one phone to another (by cable or Wi-Fi), on Android 12 or later everything is transferred, attachments included; on Android 9 to 11, photo and PDF files aren't either.
- Those backups are managed by Google in your account: you can turn them off in Android's settings. If you reinstall the app with backup on, you may get your tasks back.

## Zooming in

<!-- Fuente: specs 007 (CA-007-10), 008 (CA-008-10), 009 (CA-009-06), 017 (CA-017-13) y los ADR-0013 y 0022. -->

There are several ways to zoom in, depending on what you're looking at:

- Photos: pinch to zoom in for a quick look, up to ×8; when you let go, the photo returns to its size. There's no zoom that stays put: for that, use the system magnifier.
- PDFs: the zoom goes from ×1 to ×4 and stays put. Zoom with a pinch, a double tap (it alternates between ×1 and ×2.5) or the actions “Zoom in”, “Zoom out” and “Fit to width”; with a keyboard, the `+`, `-` and `0` keys (the last one goes back to the full width).
- Web pages: they show with whatever zoom the site itself allows.
- The system magnifier (in Android's accessibility settings, under Magnification; the name varies by phone) works across the whole app, also with “Lock zoom” on.
- Task text follows Android's font size: on the current task it grows up to 1.6 times and, if it doesn't fit, it scrolls.

## Using the app with TalkBack

<!-- Fuente: specs 003 (CA-003-07), 006 (CA-006-09, 16, 17), 008 (CA-008-10, 20), 014 (CA-014-16 a 20), 016 (CA-016-09, 20, 21) y 013, con los ADR-0013, 0020, 0022 y 0023. -->

Almost every gesture has an alternative for TalkBack, Switch Access, voice control and the keyboard. Actions are chosen in your screen reader's actions menu on the task or on the row:

- Complete: the “Complete task” action, without pressing and holding. A double tap on “Press to complete” doesn't complete, to avoid accidents.
- Delete: the “Delete task” action. The strip with “Undo” is the first thing the screen reader reads and its time stops while it has focus.
- In “All my tasks”, each row offers “Make current”, “Move up”, “Move down”, “Edit task” and “Delete task” (only the ones that can be done).
- Several photos: “Next photo” and “Previous photo”, or scroll left and right; the screen reader announces which photo it is. With a keyboard, the left and right arrow keys.
- PDFs: “Next page”, “Previous page”, “Zoom in”, “Zoom out”, “Fit to width” and the scroll actions.
- Pinch: zooming a photo with a pinch has no alternative inside the app; use the system magnifier.
- If you choose in “Settings” a language other than your phone's first one, some announcements and action names are read by the system voice, in its language.

## How to get in touch

<!-- Fuente: spec 023 (CA-023-17) y la sección «Quién es el responsable» de la política de privacidad. El contacto es un hueco de identidad que se rellena en F6. -->

For any question about the app or your privacy, write to [CONTACT]. The [privacy policy](/privacy#en) explains what the app stores and where.
