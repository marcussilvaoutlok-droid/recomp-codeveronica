// Resident Evil Code: Veronica X - ReXGlue recompiled project
//
// Application entry point implementation for the host runtime.

#pragma once

#include <memory>
#include <rex/rex_app.h>

class RecvXApp : public rex::ReXApp {
 public:
  using rex::ReXApp::ReXApp;

  static std::unique_ptr<rex::ui::WindowedApp> Create(
      rex::ui::WindowedAppContext& ctx) {
    return std::unique_ptr<RecvXApp>(
        new RecvXApp(ctx, "recvx", PPCImageConfig));
  }
};
