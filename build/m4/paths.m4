m4_dnl build/config/nvim_paths.m4:
m4_dnl
m4_dnl Configure Neovim-specific LuaRocks paths
m4_dnl
m4_dnl Load environment variable configuration:
m4_dnl - NVIM_ROCKS_DIR: base directory for Neovim rocks
m4_dnl - LUAROCKS_CONFIG: path to LuaRocks config file
m4_include(`config_env.m4')
m4_dnl Derive Neovim-related paths at build time
m4_define(`NVIM_SITE_DIR',  `NVIM_ROCKS_DIR/share/nvim/site')
m4_define(`NVIM_OPT_DIR',   `NVIM_SITE_DIR/pack/rocks/opt')
m4_define(`NVIM_START_DIR', `NVIM_SITE_DIR/pack/rocks/start')
