# Homebrew Integration

This directory contains Brewfile declarations that will be copied into your custom image at `/usr/share/ublue-os/homebrew/`.

## What are Brewfiles?

Brewfiles are Homebrew's way of declaring packages in a declarative format. They allow you to specify which packages, taps, and casks you want installed.

## How It Works

1. **During Build**: Files in this directory are copied to `/usr/share/ublue-os/homebrew/` in the image
2. **After Installation**: Users install packages by running `brew bundle` commands
3. **User Experience**: Declarative package management via Homebrew

## Usage

### Adding Brewfiles to Your Image

1. Create `.Brewfile` files in this directory
2. Add your desired packages using Brewfile syntax
3. Build your image - the Brewfiles will be copied to `/usr/share/ublue-os/homebrew/`

**No Brewfiles are included by default.** If you want to add some later, create your own files, for example:

- `default.Brewfile` - Essential command-line tools
- `development.Brewfile` - Development tools and languages
- `fonts.Brewfile` - Programming fonts

### Installing Packages from Brewfiles

After booting into your custom image, install packages with:

```bash
brew bundle --file /usr/share/ublue-os/homebrew/default.Brewfile
```

You can also create your own `ujust` shortcuts in `custom/ujust/` to run `brew bundle` with your files.

## File Format

Brewfiles use Ruby syntax:

```ruby
# Add a tap (third-party repository)
tap "homebrew/cask"

# Install a formula (CLI tool)
brew "bat"
brew "eza"
brew "ripgrep"

# Install a cask (GUI application, macOS only)
cask "visual-studio-code"
```

## Customization

Create new files like:
- `default.Brewfile` - Essential tools
- `development.Brewfile` - Dev stack
- `fonts.Brewfile` - Fonts
- `gaming.Brewfile`, `media.Brewfile`, etc.

When you add new Brewfiles, you can create corresponding `ujust` commands for easy installation.

## Resources

- [Homebrew Documentation](https://docs.brew.sh/)
- [Brewfile Documentation](https://github.com/Homebrew/homebrew-bundle)
- [Bluefin Homebrew Guide](https://docs.projectbluefin.io/administration#homebrew)
