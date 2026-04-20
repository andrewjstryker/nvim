m4_dnl build/m4/paths.m4
m4_dnl
m4_dnl Derive Neovim-specific site/pack paths from config_env.m4 values.
m4_dnl All exported symbols use the NV_M4_ prefix.
m4_dnl
m4_dnl Quoting note:
m4_dnl   The inner macro references (e.g., NV_M4_NVIM_ROCKS_DIR) are placed
m4_dnl   OUTSIDE quotes so they expand when the outer macro is invoked.
m4_dnl   The literal path suffix is inside quotes to prevent unwanted expansion.
m4_dnl
m4_include(`config_env.m4')
m4_dnl
m4_dnl Site/pack directories (used by runtimepath/packpath)
m4_define(`NV_M4_SITE_DIR',  NV_M4_NVIM_ROCKS_DIR`/share/nvim/site')
m4_define(`NV_M4_OPT_DIR',   NV_M4_SITE_DIR`/pack/rocks/opt')
m4_define(`NV_M4_START_DIR', NV_M4_SITE_DIR`/pack/rocks/start')
m4_dnl
m4_dnl rocks.nvim versioned directory — glob because the version suffix
m4_dnl (e.g., 2.47.4-1/) is unknown at render time.  Resolved at runtime
m4_dnl via vim.fn.glob().  See "NV_M4_ROCKS_RTP" in design.md.
m4_define(`NV_M4_ROCKS_RTP', NV_M4_NVIM_ROCKS_DIR`/lib/luarocks/rocks-5.1/rocks.nvim/*')

