# APEX_SObjectSetJoinUtil
集合关联工具类

因为Salesforce平台里的SOQL语句不支持两个没有做lookup关系的对象之间的关联查询，
该工具类，提供类似sql语句中通过关键字段进行inner join和left join的关联操作。是对目前SOQL一些不足的补充

功能：
  *支持多个List<SObjects>通过关键字段 进行 inner join、left join 操作
  *第一级join 允许多个字段进行关联查询，但是必须是同一个对象；在第二级及以上join查询只支持关联一个字段
  *涉及的key默认都是小写
  

目前支持三种格式的返回
1、ToMapsList
每一行记录被组装到一个Map集合中，Map集合中的key对应字段名，value对应字段值
整个记录装成一个List，最终格式是List<Map<string,Object>>

2、ToJsonList
每一行记录解析成一个json格式的字符串
整个记录组装成一个List，最终格式是List<String>
 
3、ToObjectList 
每一行记录都解析赋值到一个对象
整个记录组装成一个List，最终格式是List<Object>
在使用这个方法的时候，需要预先定义一个用来接受数据的对象，该对象的定义跟下面定义的fiedMap集合中的Value值对应，
可以将对象中定义的字段理解为，要查询对象字段的所要输出别名。
public class Test_Accounts extends BaseCustomObjectClass{
        public String new_id;
        public String new_Name;
        public String record_type;
        public String account_Id;
        public String account_Name;
        public String CN_WCCS_POC_ID;
        public String user_Id;
        public String user_Name;
        
        public override BaseCustomObjectClass parse(String json) {
            Test_Accounts t = (Test_Accounts) System.JSON.deserialize(json, Test_Accounts.class);
            t.new_id = (t.new_id=='null'?'':t.new_id)+'my test';
            t.new_Name = (t.new_Name=='null'?'':t.new_Name);
            t.user_Id = (t.user_Id=='null'?'':t.user_Id);
            t.user_Name = (String.isNotBlank(t.user_Name)?t.user_Name:'');
            t.account_Name = (t.account_Name=='null'?'':t.account_Name);
            return t;
        } 
}

工具类调用代码：

Map<string,string> fieldMap = new Map<string,string>();
fieldMap.put('userpoc_relationship__c.id','new_id');
fieldMap.put('userpoc_relationship__c.poc_id__c','new_Name');
fieldMap.put('userpoc_relationship__c.CN_User__c','record_type');
fieldMap.put('Account.id','account_Id');
fieldMap.put('Account.Name','account_Name');
fieldMap.put('User__c.id','user_Id');
fieldMap.put('User__c.Name','user_Name');


CN_SObjectsSetJoinUtil util = new CN_SObjectsSetJoinUtil();
List<cn_user_poc_relationship__c> userList =[select id,poc_id__c,User__c 
    from userpoc_relationship__c];
List<User__c> ulist =[select id,name from User__c];
List<Account> accountList =[select id,Name from Account];
 util.SetDriverList(userList)
    .SetNoDriverList(accountList)
    .OnInnerJoin(new Map<string,string>{'userpoc_relationship__c.poc_id__c' =>'Account.id'})；
   .SetNoDriverList(ulist)
    .OnInnerJoin(new Map<string,string>{'userpoc_relationship__c.User__c' =>'CN_User__c.id'});


//返回Map格式
List<Map<String,Object>> bMap = util.toMapsList(fieldMap);
//返回json格式
List<String> final12 =  util.toJsonList(fieldMap);
 
List<Test_Accounts> bcc = new List<Test_Accounts>();
//返回对象列表
util.toObjectList(fieldMap,bcc,Test_Accounts.class);
