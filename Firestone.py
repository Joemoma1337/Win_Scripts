import cv2
import keyboard
import mss
import numpy as np
import pyautogui
import threading
import time

# --- Setup ---
image_path = "upgradeX25.png"
confidence_threshold = 0.7

# Updated Resting Location
local_return_x, local_return_y = -1500, 750 

stop_script = False

# Scoped Scan Area
monitor_scope = {
    "top": 500,
    "left": -300,
    "width": 280,
    "height": 820
}

# Timer Setup (10 minutes)
last_match_time = time.time()
#TIMEOUT_LIMIT = 5 #test
#TIMEOUT_LIMIT = 180 #3 min
#TIMEOUT_LIMIT = 300 #5 min
TIMEOUT_LIMIT = 600 #10 min

# Faster clicking speed
pyautogui.PAUSE = 0.01

template = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
if template is None:
    raise FileNotFoundError(f"Could not find {image_path}")
h, w = template.shape[:2]

def perform_reset_sequence():
    """Executes the specific series of clicks when no matches are found."""
    print("\nNo matches for 10 minutes. Performing reset sequence...")
    pyautogui.press('esc')
    time.sleep(1)
    
    locations = [
        (-63, 563),#town
        (-967, 597),#temple
        (-542, 861),#empower
        (-956, 1018),#select_empower
        (-808, 1074)#confirm
        #(-975, 810)#blank
    ]
    #2x empower
    #locations = [
        #(-63, 563),
        #(-967, 597),
        #(-542, 861),
        #(-957, 1345),
        ##(-805, 1077)#final
        #(-975, 810)#blank
    #]
    
    for loc in locations:
        pyautogui.click(loc[0], loc[1])
        time.sleep(.5)
    
    global last_match_time
    last_match_time = time.time()

def monitor_keyboard():
    global stop_script
    keyboard.wait("shift")
    print("\nStopping...")
    stop_script = True

threading.Thread(target=monitor_keyboard, daemon=True).start()

with mss.mss() as sct:
    print(f"Bot started. Resting/Clicking at: ({local_return_x}, {local_return_y})")

    while not stop_script:
        # 1. Grab screenshot
        screenshot = sct.grab(monitor_scope)
        screen_gray = cv2.cvtColor(np.array(screenshot), cv2.COLOR_BGRA2GRAY)

        # 2. Match Template
        result = cv2.matchTemplate(screen_gray, template, cv2.TM_CCOEFF_NORMED)
        loc = np.where(result >= confidence_threshold)
        
        rects = []
        for pt in zip(*loc[::-1]):
            rects.append([int(pt[0]), int(pt[1]), int(w), int(h)])
            rects.append([int(pt[0]), int(pt[1]), int(w), int(h)])
        
        grouped_rects, _ = cv2.groupRectangles(rects, groupThreshold=1, eps=0.2)

        if len(grouped_rects) > 0:
            # Found upgrades!
            last_match_time = time.time()
            for (x, y, w_rect, h_rect) in grouped_rects:
                target_x = x + (w_rect // 2) + monitor_scope["left"]
                target_y = y + (h_rect // 2) + monitor_scope["top"]
                pyautogui.click(target_x, target_y)
        else:
            # No upgrades found: Move to resting spot and CLICK
            pyautogui.click(local_return_x, local_return_y)
            
            # Check for 10-minute timeout
            elapsed_time = time.time() - last_match_time
            if elapsed_time > TIMEOUT_LIMIT:
                perform_reset_sequence()
                time.sleep(5)
                pyautogui.click(-956, 1098)
                time.sleep(1)
                pyautogui.click(-495, 1330)
                time.sleep(0.25)
                pyautogui.click(-238, 1373)
                time.sleep(0.25)
                pyautogui.click(-238, 1373)
                time.sleep(0.25)
                pyautogui.click(-238, 1373)
                time.sleep(5)

        # Small delay to prevent CPU overheating
        time.sleep(0.01)

print("Script stopped.")
