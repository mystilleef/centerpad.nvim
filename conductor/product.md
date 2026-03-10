# Initial Concept
A Neovim plugin that allows users to center the main editor buffer by adding paddings to the left and right of it.

# Product Guide

## Vision
To provide a distraction-free, centered editing experience in Neovim, especially beneficial for users with large or widescreen monitors.

## Target Audience
- Neovim users who prefer a centered text area.
- Developers working on large monitors who want to reduce eye strain from looking at the far left of the screen.
- Writers and coders seeking a minimalist, focused environment.

## Core Features
- **Toggleable Centering:** Easily turn the centered padding on and off via a command (`:Centerpad`).
- **Customizable Padding:** Allow users to specify the width of the left and right padding buffers.
- **Non-intrusive Paddings:** The padding buffers are empty, cannot be modified, and cannot be focused, ensuring they don't interfere with the normal workflow.
- **Lazy.nvim Compatibility:** Designed to work seamlessly with the popular `lazy.nvim` plugin manager.

## Success Metrics
- Seamless integration with Neovim without causing layout bugs.
- High performance with no noticeable lag when toggling or resizing.
- Positive user feedback regarding the distraction-free experience.