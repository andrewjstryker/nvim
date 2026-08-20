m4_dnl build/m4/paths.m4
m4_dnl
m4_dnl Derive Neovim-specific site/pack paths from protocol context values.
m4_dnl All exported symbols use the protocol's M4_ prefix.
m4_dnl
m4_dnl Quoting note:
m4_dnl   The inner macro references (e.g., M4_NVIM_ROCKS_DIR) are placed
m4_dnl   OUTSIDE quotes so they expand when the outer macro is invoked.
m4_dnl   The literal path suffix is inside quotes to prevent unwanted expansion.
m4_dnl
m4_dnl Site/pack directories (used by runtimepath/packpath)
m4_define(`M4_SITE_DIR',  M4_NVIM_ROCKS_DIR`/share/nvim/site')
m4_define(`M4_OPT_DIR',   M4_SITE_DIR`/pack/rocks/opt')
m4_define(`M4_START_DIR', M4_SITE_DIR`/pack/rocks/start')
m4_dnl
m4_dnl rocks.nvim versioned directory — glob because the version suffix
m4_dnl (e.g., 2.47.4-1/) is unknown at render time.  Resolved at runtime
m4_dnl via vim.fn.glob().  See "M4_ROCKS_RTP" in design.md.
m4_define(`M4_ROCKS_RTP', M4_NVIM_ROCKS_DIR`/lib/luarocks/rocks-5.1/rocks.nvim/*')
