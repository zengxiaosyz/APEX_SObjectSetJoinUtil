/**
 * Collection of join tool classes
 * support multiple List<SObjects> through key field to inner join、left join operate
 * the first join allow multiple fields to union query ，but it must be the same object；the second join and above only support one field to join query
 * all key is lowercase default 
**/
public with sharing class SObjectsSetJoinUtil {
    private Boolean IsFirstJoin;//Is it the first time
    private List<SObject> DriverList;//Driver List
    private List<SObject> NoDriverList;//No Driver List
    private Map<String,Map<String,List<SObject>>> DriverMap;//generated driver Map after the first join （string:key,string:object name,List<SObject>:key to collection of object）
    private Boolean IsOutput;//Whether the result has been generated
    public SObjectsSetJoinUtil() {
        IsFirstJoin = true;//Initialization is the first time
        IsOutput = false;//default is false
    }
    /**
	 * setting the driver list
	 * @param inputList Driver List 
	**/
    public SObjectsSetJoinUtil SetDriverList(List<SObject> inputList){
        DriverList = inputList;
        return this;
    }

    /**
	 * setting the no driver list
	 * @param inputList No Driver List 
	**/
    public SObjectsSetJoinUtil SetNoDriverList(List<SObject> inputList){
        if((IsFirstJoin==true && DriverList == null)||(IsFirstJoin==false && DriverMap == null)){
            throw new InvalidJoinException('Please set the driver table first!');
        }
        NoDriverList = inputList;
        return this;
    }

    /**
	 * collections inner join
	 * @param joinFields the join key field，allow multiple fields to join.  no consider the relationship field to join,such as __r.xxx
     * Map<string,string> string组成是SObjectName.FieldName
	**/
    public SObjectsSetJoinUtil OnInnerJoin(Map<string,string> joinFields){
        if((IsFirstJoin==true && DriverList == null)||(IsFirstJoin==false && DriverMap == null)){
            throw new InvalidJoinException('Please set the driver table first!');
        }
        if(NoDriverList == null){
            throw new InvalidJoinException('Please set the no driver table!');
        }
        if(joinFields.keySet().size()<=0){
            throw new InvalidJoinException('Please set the join fields!');
        }
        //get the join field from the driver or no driver list
        List<string> driverKeyFields = new List<string>();
        List<string> noDriverKeyFields = new List<string>();
        Set<string> OnlyOneObject = new Set<string>();
        for(string key : joinFields.keySet()){
            
            if(key.split('\\.').size()!=2 ||joinFields.get(key).split('\\.').size()!=2 ){
                throw new InvalidJoinException('join fields setting error,correct format(SObjectName.FieldName)!');
            }
            OnlyOneObject.add(key.split('\\.')[0]);
            driverKeyFields.add(key);
            noDriverKeyFields.add(joinFields.get(key));
        }
        if(OnlyOneObject.size()>1){
            throw new InvalidJoinException('Join fields are only allowed to come from the same object!');
        }

        Map<String,Map<String,List<SObject>>> tempDriverTable;
        Map<String,Map<String,List<SObject>>> tempNoDriverTable;
        if(IsFirstJoin==true){
            tempDriverTable = ReConstructByList(driverKeyFields,DriverList);
        }else{
            if(driverKeyFields.size()>1 ){
                throw new InvalidJoinException('Join queries that are larger than a two-layer JOIN support only one field!');
            }
            tempDriverTable = ReConstructByMap(driverKeyFields,DriverMap);
        }
        tempNoDriverTable = ReConstructByList(noDriverKeyFields,NoDriverList);

        DriverMap = HandleInnerJoin(tempDriverTable,tempNoDriverTable);

        IsFirstJoin = false;
        return this;
    }

    /**
	 * collections left join
	 * @param joinFields the join key field，allow multiple fields to join.  no consider the relationship field to join,such as __r.xxx
     * Map<string,string> string组成是SObjectName.FieldName
	**/
    public SObjectsSetJoinUtil OnLeftJoin(Map<string,string> joinFields){
        if((IsFirstJoin==true && DriverList == null)||(IsFirstJoin==false && DriverMap == null)){
            throw new InvalidJoinException('Please set the driver table first!');
        }
        if(NoDriverList == null){
            throw new InvalidJoinException('Please set the no driver table!');
        }
        if(joinFields.keySet().size()<=0){
            throw new InvalidJoinException('Please set the join fields!');
        }
        //get the join field from the driver or no driver list
        List<string> driverKeyFields = new List<string>();
        List<string> noDriverKeyFields = new List<string>();
        Set<string> OnlyOneObject = new Set<string>();
        for(string key : joinFields.keySet()){
            
            if(key.split('\\.').size()!=2 ||joinFields.get(key).split('\\.').size()!=2 ){
                throw new InvalidJoinException('join fields setting error,correct format(SObjectName.FieldName)!');
            }
            //OnlyOneObject.put(key.split('\\.')[0], joinFields.get(key).split('\\.')[0]);
            OnlyOneObject.add(key.split('\\.')[0]);
            driverKeyFields.add(key);
            noDriverKeyFields.add(joinFields.get(key));
        }
        if(OnlyOneObject.size()>1){
            throw new InvalidJoinException('Join fields are only allowed to come from the same object!');
        }

        Map<String,Map<String,List<SObject>>> tempDriverTable;
        Map<String,Map<String,List<SObject>>> tempNoDriverTable;
        if(IsFirstJoin==true){
            tempDriverTable = ReConstructByList(driverKeyFields,DriverList);
        }else{
            if(driverKeyFields.size()>1 ){
                throw new InvalidJoinException('Associative queries that are larger than a two-layer JOIN support only one field!');
            }
            tempDriverTable = ReConstructByMap(driverKeyFields,DriverMap);
        }
        tempNoDriverTable = ReConstructByList(noDriverKeyFields,NoDriverList);
        //system.debug('tempNoDriverTable:'+tempNoDriverTable);
        DriverMap = HandleLeftJoin(tempDriverTable,tempNoDriverTable);
       
        IsFirstJoin = false;
        return this;
    }

    /**
	 * 生成自定义对象的List集合
	 * @param classFields 字段映射集合，key：前面查询的SObject.字段，value：对应要生成对象的字段
	 * @param baseCustomeList 生成对象的集合 
    **/
    public void ToObjectList(Map<string,string> classFields,List<BaseCustomObjectClass> baseCustomeList,System.Type baseCustomeClass){
        List<String> finaljsonList = CombinJoinResult(classFields);
        for(string finalStr : finaljsonList){
            BaseCustomObjectClass dem = (BaseCustomObjectClass)baseCustomeClass.newInstance();
            baseCustomeList.add(dem.parse(finalStr));

            //CN_BaseCustomeClass dem = (CN_BaseCustomeClass) System.JSON.deserialize(finalStr, baseCustomeClass);
            //baseCustomeList.add(dem);
        }
    }

    // /**
	//  * 生成自定义对象的List集合
	//  * @param classFields 字段映射集合，key：前面查询的SObject.字段，value：对应要生成对象的字段
	//  * @param baseCustomeClass 生成对象的类型 
    // **/
    // public List<BaseCustomObjectClass> ToObjectList(Map<string,string> classFields,System.Type baseCustomeClass){
    //     if(IsOutput == true){
    //         throw new InvalidJoinException('Can not Re Invoke this function !');
    //     }
    //     List<String> finaljsonList = CombinJoinResult(classFields);
    //     List<BaseCustomObjectClass> finalList = new List<BaseCustomObjectClass>();
    //     for(string finalStr : finaljsonList){
    //         BaseCustomObjectClass dem = (BaseCustomObjectClass)baseCustomeClass.newInstance();
    //         finalList.add(dem.parse(finalStr));
    //     }
    //     IsOutput = true;
    //     return finalList;
    // }

    /**
	 * 生成Json格式字符串的List集合
	 * @param pclassFields 字段映射集合，key：前面查询的SObject.字段，value：对应要生成对象的字段
    **/
    public List<String> ToJsonList(Map<string,string> pclassFields){
        if(IsOutput == true){
            throw new InvalidJoinException('Can not Re Invoke this function !');
        }
        List<String> finaljsonList = CombinJoinResult(pclassFields);
        IsOutput = true;
        return finaljsonList;
    }

    /**
	 * 生成Maps格式字符串的List集合
     * 其中Map格式：String：字段名，Object：字段值；List集合中的每一个Map集合表示一条记录
     * @param pclassFields 字段集合，key：查询的所有字段（格式：SObject.字段）, value：对应要生成的字段别名
    **/
    public List<Map<String,Object>> ToMapsList(Map<string,string> pclassFields){

        Map<string,List<string>> newFieldset = new Map<string,List<string>>();//定义重新结构
        Map<string,string> classFields = new Map<string,string>();

        ReConstructFieldMap(pclassFields,classFields,newFieldset);

        List<Map<String,Object>> finalMapList = new List<Map<String,Object>>();
        for (String key : DriverMap.keySet()) {
            //system.debug('sobjectMap:'+DriverMap.get(key));   
            Map<String,List<SObject>> sobjectMap = DriverMap.get(key);
            if(sobjectMap==null || sobjectMap.values().size()<=0){
                continue;
            }
            Integer maxIndex =0;//取最大对象记录为驱动列表
            String maxObjName = '';
            for(string objName : sobjectMap.keySet()){
                List<SObject> myList = sobjectMap.get(objName);
                if(maxIndex<myList.size()){
                    maxObjName = objName;
                    maxIndex = myList.size();
                }
            }  

            List<SObject> maxobjList = sobjectMap.remove(maxObjName);//提取最大记录的对象对应清单
            List<Map<String,Object>> tempMapList = new List<Map<String,Object>>();//保存最大记录的对象字段名称以及对应的值
            //首先将最大记录数的清单生成json格式清单
            for(SObject obj1 : maxobjList){
                /* 不能使用这种简单的方式，如果存在多级lookup查询（比如__r.xx__r.xx__c），提取不了对应的值
                Map<String, Object> values = obj1.getPopulatedFieldsAsMap();
                tempMapList.add(values);
                */

                Map<String,Object> objKeyValues = new Map<String,Object>();
                List<string> myfieldList = newFieldset.get(maxObjName.toLowerCase());
                for(string str : myfieldList){
                    string newmapfield = maxObjName+'.'+str;
                    objKeyValues.put(classFields.get(newmapfield.toLowerCase()), GetSObjectValue(obj1,(str.split('\\.'))));
                }
                tempMapList.add(objKeyValues);
            }

            //支持N:N:N....
            List<Map<String,Object>> unionMapList = new List<Map<String,Object>>();//保存中间计算的对象字段名称以及对应的值
            for(string objName : sobjectMap.keySet()){
                //system.debug('objName:'+objName);
                List<SObject> myList = sobjectMap.get(objName);
                for(SObject obj2 : myList){ //如果有多条记录的做笛卡尔集
                    if(obj2==null)
                        continue;
                    for(Map<String,Object> jsonstr: tempMapList){
                        List<string> myfieldList = newFieldset.get(objName.toLowerCase());//提取对象映射的字段
                        for(string str : myfieldList){
                            string newmapfield = objName+'.'+str;
                            jsonstr.put(classFields.get(newmapfield.toLowerCase()), GetSObjectValue(obj2,(str.split('\\.'))));
                        }
                        unionMapList.add(jsonstr);
                        //system.debug('jsonstr:'+jsonstr);
                    }
                }
                tempMapList.clear();
                for(Map<String,Object> newstr: unionMapList) //每种对象循环完成，把拼装后的字符串集合赋值，为下一个对象循环做准备
                {
                    tempMapList.add(newstr);
                }
                unionMapList.clear();//清空字符串集合，为下一个对象循环准备接受新的拼装值
            }

            for(Map<String,Object> jsonstr2: tempMapList){
                finalMapList.add(jsonstr2);
            }
   
        }
        return finalMapList;
    }

    /**
	 * 递归提取对象值
     * 主要是提取多级lookup查询的字段值
     * @param obj 提取的对象
     * @param fields 多级字段
    **/
    private Object GetSObjectValue(SObject obj,List<String> fields){
        if(fields.size()>1){
            string fieldName = fields.remove(0);//提取lookup字段名并移除
            SObject newObj = obj.getSObject(fieldName);
            return GetSObjectValue(newObj,fields);
        }else{
            return obj.get(fields[0]);
        }
        
    }

    /**
	 * 重新组装(驱动表的第一次调用组装、非驱动表)
	 * @param joinKeyField 关联字段.  不考虑relationship字段来关联比如__r.xxx,关联字段值为空的记录会过滤
	 * @param objList 驱动表的第一次调用、非驱动表 
	**/
    private Map<String,Map<String,List<SObject>>> ReConstructByList(List<string> joinKeyField,List<SObject> objList){
        Map<String,Map<String,List<SObject>>> tempMap = new Map<String,Map<String,List<SObject>>>();
        List<string> keyFieldValue = new List<string>();
        Boolean flag;
        for(SObject obj : objList){
            flag = false;
            String key;
            for(String str : joinKeyField){
                key = String.valueOf(obj.get(str.split('\\.')[1]));//根据字段名获取对应的值
                if(String.isNotBlank(key)){ //值不为空则添加到key 中，否则这条记录忽略
                    keyFieldValue.add(key);
                }else{
                    flag=true;
                    break;
                }
            }
            if(flag){
                continue;
            }
            string tempKey = String.join(keyFieldValue, '_');
            Map<String,List<SObject>> valueMap = tempMap.get(tempKey.toLowerCase());
            if(valueMap == null || valueMap.size()==0){
                tempMap.put(tempKey.toLowerCase(), new Map<String,List<SObject>>{String.valueOf(obj.getSObjectType()).toLowerCase() => new List<SObject>{obj}});
            }else{
                //将key以及对象名相等的obj加入到list中
                valueMap.get(String.valueOf(obj.getSObjectType()).toLowerCase()).add(obj);
            }
            
            keyFieldValue.clear();
        }
        return tempMap;
    }

    /**
	 * 重新组装(第一次join后生成的驱动表 调用组装)
     * 
     * 1、对于包含在关联字段的对象对应的记录需要，提取key 并过滤key为空的记录
     * 2、提取没包含在关联字段的对象对应的记录
     * 3、最后合并这个map值，并对应到新的key map映射集合中
	 * @param joinKeyField 关联字段，重组限定只允许1个字段. 关联字段对应的值为空的记录会过滤 格式：对象名.字段名
	 * @param objMap 第一次join后生成的驱动表 
	**/
    private Map<String,Map<String,List<SObject>>> ReConstructByMap(List<string> joinKeyField,Map<String,Map<String,List<SObject>>> objMap){
        Map<String,Map<String,List<SObject>>> tempMap = new Map<String,Map<String,List<SObject>>>();
        List<string> keyFieldValue = new List<string>();
        Boolean flag;
        for(string key : objMap.keySet()){
            Map<String,Map<String,List<SObject>>> tempMap2 = new Map<String,Map<String,List<SObject>>>();
            flag = false;
            String mykey;
            String existsObjName='';
            Map<String,List<SObject>> newvalueMap = new Map<String,List<SObject>>();//组装到新Map中
            Map<String,List<SObject>> oldvalueMap = objMap.get(key);
            //system.debug('oldvalueMap:'+oldvalueMap);
            //1、对于包含在关联字段的对象对应的记录需要，提取key 并过滤key为空的记录
            for(String str : joinKeyField){
                string objName = str.split('\\.')[0];//找到关联字段的对象名称
                existsObjName += ','+objName+',';

                List<SObject> objList = oldvalueMap.get(objName.toLowerCase());
                //system.debug('objList:'+objList);
                //对于List<对象>中关联字段存在多个不同值的情况，需要在最外层的Map中新创建多个Item（其中Key对应各个不同值）
                for(SObject obj : objList){
                    myKey = String.valueOf(obj.get(str.split('\\.')[1]));//根据字段名获取对应的值
                    if(String.isNotBlank(myKey)){ //值不为空则添加到key 中，否则这条记录忽略
                        if(tempMap2.containsKey(myKey)){
                            Map<String,List<SObject>> newvalueMap2 = tempMap2.get(myKey);
                            List<SObject> newobjList2 = newvalueMap2.get(objName);
                            if(newobjList2 == null || newobjList2.size()==0){
                                newvalueMap2.put(objName, new List<SObject>{obj});
                            }else{
                                newobjList2.add(obj);
                            }
                        }else{
                            tempMap2.put(myKey.toLowerCase(), new Map<String,List<SObject>>{objName => new List<SObject>{obj}});
                        }

                        //keyFieldValue.add(mykey);
                        // List<SObject> newobjList = newvalueMap.get(objName);
                        // if(newobjList == null || newobjList.size()==0){
                        //     newvalueMap.put(objName, new List<SObject>{obj});
                        // }else{
                        //     newobjList.add(obj);
                        // }
                    }
                }
            }
            //system.debug('key11:'+tempMap2.keySet().size());
            //2、提取没包含在关联字段的对象对应的记录
            ////重新组装驱动表的key； 原来的key+字符|+新的join key （这样确保在总Map中经过多次join，虽然关联的字段不同，但是这个Key不会重复）
            for(string key1 : tempMap2.keySet()){
                Map<String,List<SObject>> newvalueMap3 = tempMap2.get(key1);
                for(string noExist : oldvalueMap.keySet()){
                    if(existsObjName.indexOf(','+noExist+',')<0){
                        newvalueMap3.put(noExist, oldvalueMap.get(noExist));
                    }
                }
                tempMap.put(key+'|'+key1.toLowerCase(), newvalueMap3);//完成key替换，内容重组（关联字段为空的记录会过滤）
            }          
        }
        return tempMap;
    }

    /**
	 * Inner Join
	 * @param driverMap 组装后的驱动表. 
	 * @param noDriverMap 组装后的非驱动表 
	**/
    private Map<String,Map<String,List<SObject>>> HandleInnerJoin(Map<String,Map<String,List<SObject>>> driverMap,Map<String,Map<String,List<SObject>>> noDriverMap){
        Map<String,Map<String,List<SObject>>> resultMap = new Map<String,Map<String,List<SObject>>>();
        
        for(string key : driverMap.keySet()){
            //提取与非驱动表匹配的key
            //system.debug('key:'+key);
            List<string> keyList = key.split('\\|');
            string matchKey = keyList[keyList.size()-1];
            Map<String,List<SObject>> matchMap = noDriverMap.get(matchKey.toLowerCase());
            Map<String,List<SObject>> newMatchMap = new Map<String,List<SObject>>();//需要定义一个全新的Map

            //如果在非驱动表有匹配记录
            if(matchMap !=null && matchMap.keySet().size()>0){
                Map<String,List<SObject>> tempDriver = driverMap.get(key.toLowerCase());
                //system.debug('tempDriver:'+tempDriver);
                for(string key2 : tempDriver.keySet()){
                    List<SObject> newMatchList = tempDriver.get(key2.toLowerCase());
                    //把驱动表的原纪录，加入到新的匹配map中
                    newMatchMap.put(key2.toLowerCase(), newMatchList);
                }
                for(string key3 : matchMap.keySet()){
                    List<SObject> newMatchList = matchMap.get(key3.toLowerCase());
                    //把非驱动表的原纪录，加入到新的匹配map中
                    newMatchMap.put(key3.toLowerCase(), newMatchList);
                }
                resultMap.put(key.toLowerCase(), newMatchMap);
            }
        }
        return resultMap;
    }

    /**
	 * Left Join
	 * @param driverMap 组装后的驱动表. 
	 * @param noDriverMap 组装后的非驱动表 
	**/
    private Map<String,Map<String,List<SObject>>> HandleLeftJoin(Map<String,Map<String,List<SObject>>> driverMap,Map<String,Map<String,List<SObject>>> noDriverMap){
        Map<String,Map<String,List<SObject>>> resultMap = new Map<String,Map<String,List<SObject>>>();

        for(string key : driverMap.keySet()){
            //提取与非驱动表匹配的key
            List<string> keyList = key.split('\\|');
            string matchKey = keyList[keyList.size()-1];
            //system.debug('matchKey:'+matchKey);
            Map<String,List<SObject>> matchMap = noDriverMap.get(matchKey.toLowerCase());
            //system.debug('matchMap:'+matchMap);
            Map<String,List<SObject>> matchMap1 = new Map<String,List<SObject>>();
            Map<String,List<SObject>> tempDriver = driverMap.get(key.toLowerCase());
            for(string key2 : tempDriver.keySet()){
                matchMap1.put(key2.toLowerCase(), tempDriver.get(key2.toLowerCase()));
            }
            //如果在非驱动表有匹配记录
            if(matchMap !=null && matchMap.keySet().size()>0){
                for(string key3 : matchMap.keySet()){
                    //把驱动表的原纪录，加入到新的匹配map中
                    matchMap1.put(key3.toLowerCase(), matchMap.get(key3.toLowerCase()));
                }
                resultMap.put(key.toLowerCase(), matchMap1);
            }else{
                
                resultMap.put(key.toLowerCase(), matchMap1);
            }
        }

        return resultMap;
    }

    /**
	 * 将结果组装成最终的json集合.
	 * @param pclassFields 映射字段. 
	**/
    private List<String> CombinJoinResult(Map<string,string> pclassFields){
        List<String> finaljsonList = new List<String>();

        Map<string,string> classFields = new Map<string,string>();
        Map<string,List<string>> newFieldset = new Map<string,List<string>>();//定义重新结构
        ReConstructFieldMap(pclassFields,classFields,newFieldset);

        //system.debug('DriverMap:'+DriverMap);
        for (String key : DriverMap.keySet()) {
            Map<String,List<SObject>> sobjectMap = DriverMap.get(key);
            if(sobjectMap==null || sobjectMap.values().size()<=0){
                continue;
            }
            Integer maxIndex =0;//取最大对象记录为驱动列表
            String maxObjName = '';
            for(string objName : sobjectMap.keySet()){
                List<SObject> myList = sobjectMap.get(objName);
                if(maxIndex<myList.size()){
                    maxObjName = objName;
                    maxIndex = myList.size();
                }
            }  

            List<SObject> maxobjList = sobjectMap.remove(maxObjName);//提取最大记录的对象对应清单
            List<String> jsonstrList = new List<String>();//保存json格式的数据
            //首先将最大记录数的清单生成json格式清单
            for(SObject obj1 : maxobjList){
                String newJson = '';
                JSONGenerator gen = JSON.createGenerator(true);
                gen.writeStartObject();
                List<string> myfieldList = newFieldset.get(maxObjName.toLowerCase());
                for(string str : myfieldList){
                    string newmapfield = maxObjName+'.'+str;
                    gen.writeStringField(classFields.get(newmapfield.toLowerCase()), String.valueOf(GetSObjectValue(obj1,(str.split('\\.')))));
                }
                
                gen.writeEndObject();
                newJson = gen.getAsString();
                newJson = newJson.replace('{\n','').replace('\n}','');
                jsonstrList.add(newJson);
            }
            
            /* 只支持N:1:1
            List<String> unionjsonstrList = new List<String>();//保存json格式的数据
            //后面的只取一条
            for(string jsonstr: jsonstrList){
                for(string objName : sobjectMap.keySet()){
                    List<SObject> myList = sobjectMap.get(objName);
                    SObject obj2 = myList.size()>0?myList[0]:null;
                    if(obj2==null)
                        continue;
                    string newJson2;
                    JSONGenerator gen2 = JSON.createGenerator(true);
                    gen2.writeStartObject();
                    List<string> myfieldList = newFieldset.get(objName.toLowerCase());//提取对象映射的字段
                    for(string fieldstr : myfieldList){
                        string newmapfield = objName+'.'+fieldstr;//组装成最终的map字段
                        gen2.writeStringField(classFields.get(newmapfield.toLowerCase()), String.valueOf(obj2==null?'' : (obj2.get(fieldstr)==null?'':obj2.get(fieldstr))));
                    }
                    gen2.writeEndObject();
                    newJson2 = gen2.getAsString();
                    newJson2 = newJson2.replace('{\n','').replace('\n}','');
                    jsonstr = jsonstr+','+newJson2;
                }
                unionjsonstrList.add(jsonstr);
            }
            */

            //支持N:N:N....
            List<String> unionjsonstrList = new List<String>();//保存json格式的数据
            for(string objName : sobjectMap.keySet()){
                //system.debug('objName:'+objName);
                List<SObject> myList = sobjectMap.get(objName);
                for(SObject obj2 : myList){ //如果有多条记录的做笛卡尔集
                    //system.debug('jsonstrList11:'+jsonstrList);
                    if(obj2==null)
                        continue;
                    for(string jsonstr: jsonstrList){                        
                        string newJson2;
                        JSONGenerator gen2 = JSON.createGenerator(true);
                        gen2.writeStartObject();
                        List<string> myfieldList = newFieldset.get(objName.toLowerCase());//提取对象映射的字段
                        for(string fieldstr : myfieldList){
                            string newmapfield = objName+'.'+fieldstr;//组装成最终的map字段
                            gen2.writeStringField(classFields.get(newmapfield.toLowerCase()), String.valueOf(obj2==null?'' : (GetSObjectValue(obj2,(fieldstr.split('\\.')))==null?'':GetSObjectValue(obj2,(fieldstr.split('\\.'))))));
                        }
                        gen2.writeEndObject();
                        newJson2 = gen2.getAsString();
                        newJson2 = newJson2.replace('{\n','').replace('\n}','');
                        jsonstr = jsonstr+','+newJson2;//将上一个对象的字符串再连接这个对象的字符串值
                        unionjsonstrList.add(jsonstr);
                        //system.debug('jsonstr:'+jsonstr);
                    }
                }
                jsonstrList.clear();
                for(string newstr: unionjsonstrList) //每种对象循环完成，把拼装后的字符串集合赋值，为下一个对象循环做准备
                {
                    jsonstrList.add(newstr);
                }
                //system.debug('jsonstrList22:'+jsonstrList);
                unionjsonstrList.clear();//清空字符串集合，为下一个对象循环准备接受新的拼装值
            }

            for(string jsonstr2: jsonstrList){
                jsonstr2 = '{\n'+jsonstr2+'\n}';
                finaljsonList.add(jsonstr2);
            }
   
        }
        return finaljsonList;
    }

    /**
     * 重新组装映射字段Map集合
     * @param pclassFields 原始字段集合
     * @param classFields 转换为key小写集合
     * @param newFieldset 按对象进行分类的集合
    **/
    private void ReConstructFieldMap(Map<string,string> pclassFields,Map<string,string> classFields,Map<string,List<string>> newFieldset){
        for(string field : pclassFields.keySet()){//遍历映射字段
            classFields.put(field.toLowerCase(), pclassFields.get(field));
        }

        for(string field : classFields.keySet()){//遍历映射字段
            List<String> l1 = field.split('\\.');
            string objName = l1.remove(0);//提取对象名并移除
            List<string> fieldsList = newFieldset.get(objName.toLowerCase());
            if(fieldsList == null || fieldsList.size()==0){ 
                newFieldset.put(objName.toLowerCase(), new List<String>{String.join(l1,'.')});//存在多个lookup查询，所以去除对象名后要重新拼接字段
            }else{
                fieldsList.add(String.join(l1,'.'));//存在多个lookup查询，所以去除对象名后要重新拼接字段
            }
        }
    }

    public class InvalidJoinException extends Exception{}
}
