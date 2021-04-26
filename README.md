![image](https://user-images.githubusercontent.com/13360325/116012081-3924ca80-a5dd-11eb-89ab-9c8543302d7b.png)

# AndSafe

AndSafe is an Android app that encrypts plain text notes. With version 3, AndSafe3 is re-implemented with Flutter and is now open source.

## FAQ
**I can't remember my password. Can you help me?**

Sorry. There is no backdoor to recover lost passwords.

**How to backup my notes?**

AndSafe has no netowork function and hence it won't sync anything to cloud. You are encouraged to backup your notes off your phone regularly. Use the *Export notes* function to backup all notes into a file. Then copy the file to your computer as a backup.

Note that although exported notes are in encrypted form, you should still safeguard the backup file.

**Where are my exported notes?**

For AndSafe v2, notes are export to the folder *AndroidSafeExports* under your internal storage of your phone. For AndSafe3, it is under the app folder itself, e.g. */storage/emulated/0/Android/data/net.clarenceho.andsafe3/files/Documents*.

Note that for AndSafe3, if you uninstall the app, you will also delete all exported files.

**I used previous version of AndSafe. Can I import my notes into AndSafe3?**

AndSafe3 can import notes from AndSafe version 2 but not the other way around. Just export your notes in AndSafe, then open AndSafe3 and use the import function.

**The search function isn't working**

The full-text search can only match from beginning of whole word. For example, if the title is "Password for foobar.com", it can be found by searching "foo" / "com" / "pass" but not by "bar".

That is the limitation of the database search feature and to be backward compatible with older Android devices. Maybe in the future we can utilize another search engine.

## Technical FAQ
**What encryption algorithm is used?**

AndSafe uses AES in CBC mode with 256 bits key, which is generated by scrypt. AES implementation in Dart is by [Pointy Castle](https://pub.dev/packages/pointycastle). To improve performance, scrypt is using a native C implementation by [Colin Percival](https://github.com/Tarsnap/scrypt).

**Why each note is encrypted with a different key? Why not just use a single master key for all notes?**

The original AndSafe v1 (called AndroidSafe back then) had a feature to share individual encrypted note. Hence it needed to use the password to derive the encryption key for each note.
And that is why it take time to change password or importing notes, as the key needs to be generated for each note for encryption / decryption.

## Acknowledgement
- App icon: from [DelliPack](https://www.smashingmagazine.com/2008/07/55-free-high-quality-icon-sets/#dellipack), by [Wendell Fernandes](http://dellustrations.deviantart.com/)

