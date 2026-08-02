"""Tests for reading an aircraft's clickable cockpit controls out of its DCS module."""

import unittest

from veaf_libs.cockpit_controls import (
    parse_aircraft,
    parse_argument_constants,
    parse_controls,
    parse_prototypes,
    to_index,
)

# Trimmed from the F-16C's clickable_defs.lua, keeping one of each shape the parser has
# to cope with: a literal window, a window defaulted through a local, and one computed
# from the call's own arguments.
DEFS_LUA = """
local function button_prototype(hint_,device_,command_,arg_)
	return	{
				class				= {class_type.BTN},
				arg					= {arg_},
				arg_value			= {1},
				arg_lim				= {{0,1}},
			}
end

function default_button(hint_,device_,command_,arg_,animation_speed_)
	local	button = button_prototype(hint_,device_,command_,arg_)
	button.sound = {{SOUND_SW5_ON, SOUND_SW5_OFF}}
	return button
end

function default_2_position_tumb(hint_,device_,command_,arg_,animation_speed_)
	return	{
				class			= {class_type.TUMB,class_type.TUMB},
				arg				= {arg_,arg_},
				arg_value		= {-1,1},
				arg_lim			= {{0,1},{0,1}},
			}
end

function default_3_position_tumb(hint_,device_,command_,arg_,cycled_,animation_speed_,inversed_,arg_value_,arg_limit_)
	local	arg_value			= arg_value_ or 1
	local	arg_limit			= arg_limit_ or {-1,1}
	return	{
				class			= {class_type.TUMB,class_type.TUMB},
				arg				= {arg_,arg_},
				arg_value		= {-arg_value, arg_value},
				arg_lim			= {arg_limit,arg_limit},
			}
end

function springloaded_3_pos_tumb(hint_,device_,command1_,command2_,arg_,animation_speed_,val1_,val2_,val3_)
	local	val1				= val1_ or -1.0
	return	{
				class				= {class_type.BTN,class_type.BTN},
				arg					= {arg_,arg_},
				arg_lim				= {{-1,0},{0,1}},
			}
end

function default_2_position_tumb_small(hint_,device_,command_,arg_,animation_speed_)
	local	element	= default_2_position_tumb(hint_,device_,command_,arg_,animation_speed_)
	element.sound	= {{SOUND_SW3}}
	return element
end

function short_way_button(hint_,device_,command_,arg_)
	local	button = button_prototype(hint_,device_,command_,arg_)
	button.sound = {{SOUND_SW4_OFF, SOUND_SW4_ON}}
	return button
end

function multiposition_switch(hint_,device_,command_,arg_,count_,delta_,inversed_,min_)
	return	{
				arg			= {arg_},
				arg_lim		= {	{min_, min_ + delta_ * (count_ -1)}},
			}
end
"""

# Real lines, verbatim apart from the alignment.
CLICKABLE_LUA = """
elements["PTR-ELEC-TMB-MPWR-510"] = default_3_position_tumb(_("MAIN PWR Switch, MAIN PWR/BATT/OFF"), devices.ELEC_INTERFACE, elec_commands.MainPwrSw, 510, false, anim_speed_default, false)
elements["PTR-THRTL-RLS-757"] = default_button(_("Throttle, OFF/IDLE"), devices.CONTROL_INTERFACE, control_commands.ThrottleOnOff, 757)
elements["PTR-THRTL-RLS-757"].updatable = true
elements["PTR-FLTCP-TMB-DIGITAL-566"] = default_2_position_tumb(_("DIGITAL BACKUP Switch, OFF/BACKUP"), devices.CONTROL_INTERFACE, control_commands.DigitalBackup, 566)
elements["PTR-ENGSTART-TMB-JETFUEL-447"] = springloaded_3_pos_tumb(_("JFS Switch, START 1/OFF/START 2"), devices.ENGINE_INTERFACE, engine_commands.JfsSwStart1, engine_commands.JfsSwStart2, 447)
elements["PTR-EXTLGT-TMB-ANTCOL-531"] = multiposition_switch(_("ANTI-COLL Knob, OFF/1/2/3/4/A/B/C"), devices.EXTLIGHTS_SYSTEM, extlights_commands.AntiCollKn, 531, 8, 0.1, NOT_INVERSED, 0.0)
elements["PTR-AOA-LVL-794"] = default_axis_limited_1_side(_("AOA Indexer Dimming Lever"), devices.CPTLIGHTS_SYSTEM, cptlights_commands.IndBrtAoA, 794, 0, 0.1)
"""


# Two dialects the F-16C does not use. The AH-64D, a two-seater, names the crew station
# before the hint; Heatblur's F-14 names its arguments instead of writing them out.
OTHER_DIALECTS_LUA = """
elements["pnt_20"] = default_button(CREW.PLT, _("Left MPD Pushbutton, T1"), devices.MFD_PLT_LEFT, mpd_commands.T1, 20)
elements["PNT_629"] = default_2_position_tumb(_("Hydraulic Transfer Pump Switch"), devices.HYDRAULICS, device_commands.HYD_TRANSFER_PUMP_Switch, cockpit_args.HYD_TRANSFER_PUMP_Switch, pilot_only)
"""

DRAW_ARGS_LUA = """
cockpit_args =
{
    HYD_TRANSFER_PUMP_Switch = 629,
    HYDRAULICS = 4242,
}
"""


class TestOtherDialects(unittest.TestCase):
    """Shapes other modules use, each found by indexing a real cockpit."""

    def setUp(self):
        self.constants = parse_argument_constants(DRAW_ARGS_LUA)
        self.by_element = {
            control.element: control
            for control in parse_controls(OTHER_DIALECTS_LUA, parse_prototypes(DEFS_LUA), self.constants)
        }

    def test_an_argument_before_the_hint_is_ignored(self):
        self.assertEqual(20, self.by_element["pnt_20"].argument)

    def test_a_named_argument_is_resolved(self):
        self.assertEqual(629, self.by_element["PNT_629"].argument)

    def test_a_reference_is_only_resolved_against_the_table_it_names(self):
        # `devices.HYDRAULICS` comes before the argument and the constants table happens
        # to hold a HYDRAULICS too; taking it would silently give the wrong argument.
        self.assertNotEqual(4242, self.by_element["PNT_629"].argument)

    def test_a_module_without_named_arguments_needs_no_table(self):
        self.assertEqual({}, parse_argument_constants(""))


class TestPrototypes(unittest.TestCase):
    """Reading the constructors, and what each says about its window."""

    def setUp(self):
        self.prototypes = parse_prototypes(DEFS_LUA)

    def test_a_literal_window_is_read(self):
        self.assertEqual((0.0, 1.0), self.prototypes["default_2_position_tumb"].arg_lim)

    def test_a_window_defaulted_through_a_local_is_read(self):
        # `local arg_limit = arg_limit_ or {-1,1}` then `arg_lim = {arg_limit, arg_limit}`.
        self.assertEqual((-1.0, 1.0), self.prototypes["default_3_position_tumb"].arg_lim)

    def test_a_computed_window_is_left_unknown_rather_than_guessed(self):
        self.assertIsNone(self.prototypes["multiposition_switch"].arg_lim)

    def test_a_spring_loaded_control_is_not_readable(self):
        self.assertFalse(self.prototypes["springloaded_3_pos_tumb"].readable)

    def test_a_button_is_not_readable(self):
        self.assertFalse(self.prototypes["default_button"].readable)

    def test_a_switch_is_readable(self):
        self.assertTrue(self.prototypes["default_3_position_tumb"].readable)

    def test_a_variant_inherits_the_window_of_what_it_delegates_to(self):
        # Half the F-16C's controls are built from a `_small` variant that only adds a
        # sound; not following the call would leave their window unknown for nothing.
        self.assertEqual((0.0, 1.0), self.prototypes["default_2_position_tumb_small"].arg_lim)

    def test_a_variant_does_not_inherit_readability(self):
        # short_way_button delegates to a prototype with a perfectly good window and is
        # still a button, with no position to read.
        self.assertEqual((0.0, 1.0), self.prototypes["short_way_button"].arg_lim)
        self.assertFalse(self.prototypes["short_way_button"].readable)


class TestControls(unittest.TestCase):
    """Reading the elements themselves."""

    def setUp(self):
        self.by_element = {
            control.element: control for control in parse_controls(CLICKABLE_LUA, parse_prototypes(DEFS_LUA))
        }

    def test_the_argument_is_the_first_bare_integer_of_the_call(self):
        # Not the first number: `devices.X` and `commands.Y` come first, and a
        # multiposition switch has count and delta after its argument.
        self.assertEqual(510, self.by_element["PTR-ELEC-TMB-MPWR-510"].argument)
        self.assertEqual(531, self.by_element["PTR-EXTLGT-TMB-ANTCOL-531"].argument)

    def test_positions_come_from_the_hint_in_hint_order(self):
        # Deliberately NOT value order: this switch runs +1 / 0 / -1.
        self.assertEqual(["MAIN PWR", "BATT", "OFF"], self.by_element["PTR-ELEC-TMB-MPWR-510"].positions)

    def test_a_hint_with_no_position_list_yields_none(self):
        self.assertEqual([], self.by_element["PTR-AOA-LVL-794"].positions)

    def test_the_window_comes_from_the_prototype(self):
        self.assertEqual((-1.0, 1.0), self.by_element["PTR-ELEC-TMB-MPWR-510"].arg_lim)
        self.assertEqual((0.0, 1.0), self.by_element["PTR-FLTCP-TMB-DIGITAL-566"].arg_lim)

    def test_readability_follows_the_prototype(self):
        self.assertTrue(self.by_element["PTR-ELEC-TMB-MPWR-510"].readable)
        self.assertFalse(self.by_element["PTR-ENGSTART-TMB-JETFUEL-447"].readable)
        self.assertFalse(self.by_element["PTR-THRTL-RLS-757"].readable)

    def test_an_unknown_prototype_still_yields_a_control(self):
        # default_axis_limited_1_side is not in the trimmed defs; the element is still
        # useful, only its window is unknown.
        control = self.by_element["PTR-AOA-LVL-794"]
        self.assertEqual(794, control.argument)
        self.assertIsNone(control.arg_lim)

    def test_a_property_assignment_is_not_mistaken_for_an_element(self):
        # `elements["…"].updatable = true` must not produce a second control.
        self.assertEqual(1, sum(1 for e in self.by_element if e == "PTR-THRTL-RLS-757"))


class TestAircraftIndex(unittest.TestCase):
    """The whole-aircraft result and what gets written."""

    def test_nothing_is_skipped_silently(self):
        parsed = parse_aircraft("F-16C_50", CLICKABLE_LUA, DEFS_LUA)
        self.assertEqual(0, parsed.skipped)
        self.assertEqual(6, len(parsed.controls))

    def test_an_element_without_an_argument_is_counted_as_skipped(self):
        lua = CLICKABLE_LUA + '\nelements["PTR-ODD"] = weird_thing(_("Odd, A/B"), devices.X, commands.Y)\n'
        parsed = parse_aircraft("F-16C_50", lua, DEFS_LUA)
        self.assertEqual(1, parsed.skipped)

    def test_the_index_keeps_the_hint_order_and_marks_it(self):
        index = to_index(parse_aircraft("F-16C_50", CLICKABLE_LUA, DEFS_LUA), module="F-16C")
        entry = index["controls"]["PTR-ELEC-TMB-MPWR-510"]
        self.assertEqual(["MAIN PWR", "BATT", "OFF"], entry["positions"])
        self.assertEqual([-1.0, 1.0], entry["range"])
        self.assertEqual("F-16C_50", index["aircraft"])
        self.assertEqual("F-16C", index["module"])

    def test_a_multiposition_knob_gets_its_window_from_its_call(self):
        # multiposition_switch(…, arg, count, delta, inversed, min): the prototype cannot
        # fix the window, the call can — 8 positions of 0.1 from 0.0.
        by_element = {c.element: c for c in parse_controls(CLICKABLE_LUA, parse_prototypes(DEFS_LUA))}
        window = by_element["PTR-EXTLGT-TMB-ANTCOL-531"].arg_lim
        assert window is not None
        self.assertAlmostEqual(0.0, window[0])
        self.assertAlmostEqual(0.7, window[1])

    def test_an_unknown_window_is_null_in_the_index(self):
        index = to_index(parse_aircraft("F-16C_50", CLICKABLE_LUA, DEFS_LUA), module="F-16C")
        # Built from a prototype the defs do not describe.
        self.assertIsNone(index["controls"]["PTR-AOA-LVL-794"]["range"])


if __name__ == "__main__":
    unittest.main()
