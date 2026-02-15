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
m4_dnl Guard: config_env.m4 must define NV_M4_NVIM_ROCKS_DIR before we
m4_dnl derive paths from it.  Fail loudly if the include order is wrong.
m4_ifdef(`NV_M4_NVIM_ROCKS_DIR',,`m4_errprint(`paths.m4: NV_M4_NVIM_ROCKS_DIR is not defined.
  Ensure config_env.m4 is generated (run make) and uses the NV_M4_ prefix.
')m4_m4exit(`1')')m4_dnl
m4_dnl
m4_define(`NV_M4_SITE_DIR',  NV_M4_NVIM_ROCKS_DIR`/share/nvim/site')
m4_define(`NV_M4_OPT_DIR',   NV_M4_SITE_DIR`/pack/rocks/opt')
m4_define(`NV_M4_START_DIR', NV_M4_SITE_DIR`/pack/rocks/start')
