# python3 -m venv /path/to/dir
# source /path/to/dir/bin/activate
# python -m pip install --upgrade pip
# pip install opencv-python pyautogui mss keyboard
import cv2
import numpy as np
import pyautogui
import mss
import time
import keyboard
import threading

# Load the template image
template_path = "clip.png"
template = cv2.imread(template_path, cv2.IMREAD_UNCHANGED)
template_gray = cv2.cvtColor(template, cv2.COLOR_BGR2GRAY)
w, h = template_gray.shape[::-1]
threshold = 0.7  # Match confidence threshold

stop_script = False

def monitor_shift_key():
    global stop_script
    while True:
        if keyboard.is_pressed("q"):
            print("Shift key pressed. Stopping script...")
            stop_script = True
            break
        time.sleep(0.1)

def find_unique_matches(screenshot, monitor):
    gray_img = cv2.cvtColor(screenshot, cv2.COLOR_BGR2GRAY)
    result = cv2.matchTemplate(gray_img, template_gray, cv2.TM_CCOEFF_NORMED)
    locations = np.where(result >= threshold)
    points = list(zip(*locations[::-1]))

    # Deduplicate close matches
    unique_points = []
    for pt in points:
        if not any(np.linalg.norm(np.array(pt) - np.array(up)) < 10 for up in unique_points):
            unique_points.append(pt)

    # Sort bottom to top
    unique_points.sort(key=lambda p: p[1], reverse=True)

    # Convert to screen coordinates
    screen_points = [
        (monitor["left"] + pt[0] + w // 2, monitor["top"] + pt[1] + h // 2)
        for pt in unique_points
    ]
    return screen_points

# Start shift-key monitor thread
threading.Thread(target=monitor_shift_key, daemon=True).start()

# --- New Window Selection Logic ---
window_title_part = "Coupons"
target_window = None

while not target_window:
    print(f"Looking for a window with '{window_title_part}' in its title...")
    try:
        target_window = gw.getWindowsWithTitle(window_title_part)[0]
    except IndexError:
        print("Window not found. Waiting and trying again...")
        time.sleep(2)

print(f"Found target window: {target_window.title}")
target_window.activate()
time.sleep(1) # Give it a moment to become active

# Setup monitor using the window's dimensions
# Note: On some systems, sct.monitors may not recognize a specific window.
# The best way is to manually create the bounding box for the screenshot.
monitor = {
    "top": target_window.top,
    "left": target_window.left,
    "width": target_window.width,
    "height": target_window.height,
}

print(f"Using window dimensions: {monitor}")

# --- Main Loop ---
with mss.mss() as sct:
    while not stop_script:
        screenshot = np.array(sct.grab(monitor))
        matches = find_unique_matches(screenshot, monitor)

        if matches:
            print(f"Found {len(matches)} match(es)")
            for x, y in matches:
                if stop_script: break
                pyautogui.moveTo(x, y)
                time.sleep(0.2)
                pyautogui.click()
                time.sleep(0.2)

            if stop_script: break

            time.sleep(0.5)
            pyautogui.press("pagedown")
            time.sleep(0.75)
        else:
            print("No more matches found. Exiting.")
            break
