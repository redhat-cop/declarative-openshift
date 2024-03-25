from kubernetes import client, config
from kubernetes.client.rest import ApiException
from pprint import pprint
import urllib3

# Disable HTTP connection warning
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Load default kubeconfig
config.load_kube_config()

v1 = client.ApisApi()

# Start writing file
f = open("prune-whitelist.txt", "w") 

try:
  api_resources = v1.get_api_versions()
  for group in api_resources.groups:
    versions = group.versions
    group_name = group.name
    for version in versions:
      version_name = version.version
      v2 = client.CustomObjectsApi()
      api_resp_2 = v2.list_cluster_custom_object(group_name, version_name, '')
      if (api_resp_2['resources'] is not None) \
        and (api_resp_2['resources'][0] is not None) \
        and (api_resp_2['groupVersion'] is not None): 
        print ("%s/%s" % (api_resp_2['groupVersion'], api_resp_2['resources'][0]['kind']))      
        f.write("--prune-whitelist " + api_resp_2['groupVersion'] + "/" + api_resp_2['resources'][0]['kind'] + "\n")
except ApiException as e:
  print("Exception: %s\n" % e)

# Close file stream
f.close()