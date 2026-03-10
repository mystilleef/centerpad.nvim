# Product Guidelines

## Design Principles
- **Minimalism:** The plugin should do one thing well—center the buffer—without adding unnecessary visual clutter or complex configuration options.
- **Non-Intrusive:** The padding buffers must be completely transparent to the user's workflow. They should not be selectable, modifiable, or interfere with window navigation.
- **Performance:** Toggling the centerpad or resizing the window should be instantaneous and not introduce any lag.

## Code Style & Conventions
- **Language:** Lua (Neovim 0.5+ compatible).
- **Formatting:** Use `stylua` for consistent code formatting.
- **Linting:** Use `luacheck` and `selene` to catch potential errors and enforce best practices.
- **Testing:** Use `busted` for unit testing to ensure reliability.

## User Experience (UX)
- **Simplicity:** The default configuration should work out-of-the-box for most users.
- **Flexibility:** Allow users to easily customize the padding width via simple commands or configuration options.
- **Documentation:** Provide clear, concise documentation in the `README.md` and Vim help files (`doc/centerpad.txt`).