"""FIX-CONVERT-V5-COMMENTS — convert-v5 must ignore Lua comments.

In the standard VEAF template, each module body is shipped inside a
``--[[ … ]]`` "uncomment to enable" block. convert-v5 must NOT:
  1. mark a module active from the ``if veafXxx then`` guard alone when its
     entire body is commented out;
  2. regex-scan ASSETS/QRA (or any) definitions *inside* ``--[[ ]]`` blocks and
     emit phantom entries into ``mission.yaml``.
"""

from __future__ import annotations

from mission_builder.config_migrator import ConfigMigrator, _strip_lua_comments


class TestStripLuaComments:
    def test_line_comment_blanked_preserving_offsets(self) -> None:
        src = "local x = 1 -- a comment\n"
        out = _strip_lua_comments(src)
        assert len(out) == len(src)
        assert out.count("\n") == src.count("\n")
        assert "comment" not in out
        assert "local x = 1" in out

    def test_block_comment_blanked(self) -> None:
        src = "before\n--[[\nveafAssets.Assets = {}\n]]\nafter\n"
        out = _strip_lua_comments(src)
        assert "veafAssets.Assets" not in out
        assert "before" in out
        assert "after" in out

    def test_leveled_block_comment_blanked(self) -> None:
        src = '--[==[\nname="ghost"\n]==]\nactive=1\n'
        out = _strip_lua_comments(src)
        assert "ghost" not in out
        assert "active=1" in out

    def test_double_dash_inside_string_not_a_comment(self) -> None:
        src = 'local s = "a -- b"\n'
        out = _strip_lua_comments(src)
        assert "a -- b" in out

    def test_long_string_not_treated_as_comment(self) -> None:
        # A bare [[ ... ]] is a long string, NOT a comment — left intact.
        src = "x = [[\nveafAssets.Assets = {}\n]]\n"
        out = _strip_lua_comments(src)
        assert "veafAssets.Assets" in out


class TestCommentedAssetsBlock:
    """Reproduces the Training-Syrie R7 bug: a fully-commented ASSETS block."""

    def setup_method(self) -> None:
        self.m = ConfigMigrator()

    # Mirrors the standard VEAF template: active guard, body in --[[ ]],
    # plus an asset row that is also individually line-commented.
    _CONFIG = (
        "if veafAssets then\n"
        "    -- uncomment (and adapt) the following lines to enable the ASSETS module\n"
        "    --[[\n"
        '    veaf.loggers.get(veaf.Id):info("Loading configuration")\n'
        "    veafAssets.Assets = {\n"
        '        {sort=1, name="CSG-74 Stennis", description="Stennis (CVN)"},\n'
        '        -- {sort=2, name="T1-Arco-1", description="Arco-1 (KC-135)"},\n'
        "    }\n"
        '    veaf.loggers.get(veaf.Id):info("init - veafAssets")\n'
        "    veafAssets.initialize()\n"
        "    ]]\n"
        "end\n"
    )

    def test_no_phantom_assets_extracted(self) -> None:
        result = self.m.migrate(self._CONFIG)
        assert not result.assets_extracted

    def test_module_not_enabled(self) -> None:
        result = self.m.migrate(self._CONFIG)
        assert "ASSETS" not in result.enabled_modules

    def test_active_assets_still_extracted(self) -> None:
        # Sanity: an *active* (uncommented) ASSETS block is still extracted.
        active = (
            "if veafAssets then\n"
            "    veafAssets.Assets = {\n"
            '        {sort=1, name="Real-1"},\n'
            "    }\n"
            "    veafAssets.initialize()\n"
            "end\n"
        )
        result = self.m.migrate(active)
        assert result.assets_extracted
        assert result.assets_extracted[0]["name"] == "Real-1"
        assert "ASSETS" in result.enabled_modules


class TestCommentedQraChain:
    def setup_method(self) -> None:
        self.m = ConfigMigrator()

    def test_no_phantom_qra_from_block_comment(self) -> None:
        config = (
            "if veafQRA then\n"
            "    --[[\n"
            "    local q = VeafQRA:new()\n"
            '        :setName("GhostQRA")\n'
            "        :setCoalition(coalition.side.RED)\n"
            "        :start()\n"
            "    ]]\n"
            "end\n"
        )
        result = self.m.migrate(config)
        assert result.qra_definitions == []
        assert "QRA" not in result.enabled_modules


class TestCommentedGuardDoesNotEnableModule:
    """A guard whose body is only line-comments must not enable the module."""

    def setup_method(self) -> None:
        self.m = ConfigMigrator()

    def test_line_commented_body_not_enabled(self) -> None:
        config = "if veafMove then\n    -- veafMove.initialize()\nend\n"
        result = self.m.migrate(config)
        assert "MOVE" not in result.enabled_modules
