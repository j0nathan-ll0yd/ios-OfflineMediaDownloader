import json
import subprocess
import os
import sys

def get_json(xcresult_path, id=None):
    cmd = ["xcrun", "xcresulttool", "get", "object", "--legacy", "--path", xcresult_path, "--format", "json"]
    if id:
        cmd.extend(["--id", id])
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error getting JSON for id {id}: {result.stderr}")
        return None
    return json.loads(result.stdout)

def export_attachment(xcresult_path, attachment_id, output_path):
    cmd = ["xcrun", "xcresulttool", "export", "object", "--legacy", "--path", xcresult_path, "--id", attachment_id, "--output-path", output_path, "--type", "file"]
    subprocess.run(cmd, check=True)

def find_attachments(obj, found_attachments, xcresult_path):
    if isinstance(obj, dict):
        type_name = obj.get("_type", {}).get("_name")
        if type_name:
           print(f"Seen type: {type_name}")
            
        if type_name == "ActionTestAttachment":
            name = obj.get("name", {}).get("_value")
            payload_ref = obj.get("payloadRef", {}).get("id", {}).get("_value")
            if name and payload_ref:
                print(f"Found attachment: {name}, ref: {payload_ref}")
                found_attachments.append((name, payload_ref))
        
        if type_name == "ActionTestMetadata":
             summary_ref = obj.get("summaryRef", {}).get("id", {}).get("_value")
             if summary_ref:
                 print(f"Fetching summaryRef: {summary_ref}")
                 summary = get_json(xcresult_path, summary_ref)
                 find_attachments(summary, found_attachments, xcresult_path)

        for key, value in obj.items():
            find_attachments(value, found_attachments, xcresult_path)
    elif isinstance(obj, list):
        for item in obj:
            find_attachments(item, found_attachments, xcresult_path)

def main():
    if len(sys.argv) != 3:
        print("Usage: python3 extract_screenshots.py <xcresult_path> <output_dir>")
        sys.exit(1)

    xcresult_path = sys.argv[1]
    output_dir = sys.argv[2]

    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    print(f"Processing {xcresult_path}...")
    
    # Root object
    root = get_json(xcresult_path)
    if not root:
        return

    print("Root keys:", root.keys())
    
    actions = root.get("actions", {}).get("_values", [])
    print(f"Found {len(actions)} actions.")
    for action in actions:
        ar = action.get("actionResult", {})
        
        # Try testsRef
        tests_ref = ar.get("testsRef", {}).get("id", {}).get("_value")
        print(f"Tests Ref: {tests_ref}")
        
        if tests_ref:
             tests_result = get_json(xcresult_path, tests_ref)
             print(f"Tests Result keys: {tests_result.keys()}")
             # Traverse this for attachments
             attachments = []
             find_attachments(tests_result, attachments, xcresult_path)
             
             print(f"Found {len(attachments)} attachments in tests result.")
             
             for name, payload_id in attachments:
                 # Clean up name for filename
                 safe_name = "".join([c for c in name if c.isalpha() or c.isdigit() or c in (' ', '-', '_')]).rstrip()
                 if not safe_name.endswith(".png"):
                     safe_name += ".png"
                 
                 out_path = os.path.join(output_dir, safe_name)
                 print(f"Exporting {safe_name}...")
                 try:
                    export_attachment(xcresult_path, payload_id, out_path)
                 except Exception as e:
                     print(f"Failed to export {safe_name}: {e}")

if __name__ == "__main__":
    main()
