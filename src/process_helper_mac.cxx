// Subprocess helper for macOS. On macOS, CEF requires separate helper app
// bundles for GPU, Renderer, Plugin, and Alerts subprocesses. Each helper
// loads CEF via LoadInHelper() (which resolves the framework path relative
// to the helper's location inside Frameworks/) and then calls
// CefExecuteProcess to handle the subprocess logic.
//
// Browser::App is included so that the render subprocess has the custom
// JavaScript bindings (window.s(), etc.) needed by the launcher UI.

#include "browser/app.hxx"
#include "include/wrapper/cef_library_loader.h"

int main(int argc, char* argv[]) {
	CefScopedLibraryLoader library_loader;
	if (!library_loader.LoadInHelper()) {
		return 1;
	}

	Browser::App cef_app_;
	CefRefPtr<Browser::App> cef_app = &cef_app_;

	CefMainArgs main_args(argc, argv);
	return CefExecuteProcess(main_args, cef_app, nullptr);
}
