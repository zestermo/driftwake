// Driftwake native: registers the classes GDScript calls (with a GDScript fallback when the library isn't loaded).
#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

#include "chain_solver.h"

using namespace godot;

void initialize_driftwake(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(ChainSolver);
}

void uninitialize_driftwake(ModuleInitializationLevel p_level) {
}

extern "C" {
GDExtensionBool GDE_EXPORT driftwake_native_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_driftwake);
	init_obj.register_terminator(uninitialize_driftwake);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
