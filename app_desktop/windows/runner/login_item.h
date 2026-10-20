#ifndef RUNNER_LOGIN_ITEM_H_
#define RUNNER_LOGIN_ITEM_H_

// Starting the app when the user signs in, through the per-user startup
// list (HKCU\...\Run). No administrator rights needed, and it shows up in
// Task Manager's Startup apps where the user can turn it off too.
namespace login_item {

// True when the startup list points at this copy of the app.
bool IsEnabled();

// Adds or removes this copy of the app. Returns false if Windows refused.
bool SetEnabled(bool enabled);

}  // namespace login_item

#endif  // RUNNER_LOGIN_ITEM_H_
