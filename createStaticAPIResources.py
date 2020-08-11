import subprocess

apiResources = {}

apiResGatherCmd1=["oc","get","--raw","/apis"]
apiResGatherCmd2=["jq","-r",".groups[].versions[].groupVersion"]
apiResGatherProc1 = subprocess.Popen(apiResGatherCmd1, stdout=subprocess.PIPE)
apiResGatherProc2 = subprocess.Popen(apiResGatherCmd2, stdin=apiResGatherProc1.stdout, stdout=subprocess.PIPE)
for item in apiResGatherProc2.stdout.readlines():
   apiResData = str(item).replace('b\'','').replace('\'','').replace('\\n','')
   if not apiResData in apiResources:
      apiResources[apiResData] = []

f = open("prune-whitelist.txt", "w")         
for apiRes in apiResources.keys():   
   apiKindGatherCmd1=["oc","get","--raw","/apis/"+apiRes]
   apiKindGatherCmd2=["jq", "-r", ".resources[]|select(.categories)|.kind"]   
   apiKindGatherProc1 = subprocess.Popen(apiKindGatherCmd1, stdout=subprocess.PIPE)   
   apiKindGatherProc2 = subprocess.Popen(apiKindGatherCmd2, stdin=apiKindGatherProc1.stdout, stdout=subprocess.PIPE)
   for item in apiKindGatherProc2.stdout.readlines():
      apiKindData = str(item).replace('b\'','').replace('\'','').replace('\\n','')      
      print(apiRes + "/" + apiKindData)
      if not apiKindData in apiResources.get(apiRes):
         apiResources.get(apiRes).append(apiKindData)         
         f.write("--prune-whitelist " + apiRes + "/" + apiKindData + "\n")

f.close()