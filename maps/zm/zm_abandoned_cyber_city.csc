// =============================================================================
// zm_abandoned_cyber_city.csc - map entry script (client-side)
//
// Client counterpart to zm_abandoned_cyber_city.gsc. Runs on each player's
// machine. Responsible for local HUD, FX, audio triggers, and clientfield
// handlers. Gameplay/logic decisions are always authoritative on the server
// (the .gsc file).
// =============================================================================

#using scripts\codescripts\struct;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_load;
#using scripts\zm\_zm;

// Client-side stubs for our custom systems live alongside their GSC siblings.
// Most of our systems are server-authoritative; the client modules are thin.
#using scripts\zm\zm_abandoned_cyber_city\_acc_main;

main()
{
    level.map_name = "zm_abandoned_cyber_city";

    _load::main();

    level thread _acc_main::client_init();

    _zm::main();
}
