public with sharing class LWCDataTableController {
    
    @AuraEnabled(cacheable=true)
    public static DataTableWrapper initRecords(String ObjectName, String fieldNamesStr, String recordId, String Orderby, String OrderDir, boolean inlineEdit, boolean enableColAction) {
        DataTableWrapper dtw = new DataTableWrapper();
        List<LabelDescriptionWrapper> labelList = new List<LabelDescriptionWrapper>();
        List<String> fieldSet = new List<String>();
        System.debug(fieldNamesStr);
        Set<String> fieldNameSet = new Set<String>(fieldNamesStr.split(','));
        
        if(Schema.getGlobalDescribe().containsKey(ObjectName) ) {
            sObject sObj = Schema.getGlobalDescribe().get(ObjectName).newSObject() ;
            
            //get all the labels for Opportunity fields and put them in a map, keyed to the field api name
            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(ObjectName).getDescribe().fields.getMap();
            Map<Schema.SObjectField,String> fieldToAPIName = new Map<Schema.SObjectField,String>();
            Map<String, String> apiNameToLabel = new Map<String, String>();
            for(String fieldName :  fieldNameSet){
                if(fieldMap.containsKey(fieldName)) {
                    fieldSet.add(fieldName);
                    labelList.add(new LabelDescriptionWrapper(fieldMap.get(fieldName).getDescribe().getLabel(), fieldName, fieldMap.get(fieldName).getDescribe().getType().name().toLowerCase(), true, inlineEdit, null  ));
                }
            }
            system.debug('---------------------');
            //labelList.add(new LabelDescriptionWrapper('Owner Name', 'Owner.Name', 'String', true,false, null ));
            if(enableColAction) {
                List<Actions> actionList = new List<Actions>();
                actionList.add(new Actions('Edit','edit'));
                actionList.add(new Actions('View','view'));
                actionList.add(new Actions('Delete','delete'));
                TypeAttributes tAttribute = new TypeAttributes(actionList);
                
                labelList.add(new LabelDescriptionWrapper('', '', 'action', false, false, tAttribute ));
            }
            //call method to query
            List<sObject> sObjectRecords = getsObjectRecords(ObjectName, fieldSet, 150, recordId, Orderby, OrderDir);
            dtw.ldwList 	= labelList;
            dtw.sobList 	= sObjectRecords;
            dtw.fieldsList 	= fieldSet;
            dtw.totalCount  = Database.countQuery('SELECT count() FROM '+ObjectName);
        }
        return dtw;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<sObject> getsObjectRecords(String ObjectName, List<String> fieldNameSet, Integer LimitSize, String recId, String Orderby, String OrderDir) {
        // /,Owner.Name
        OrderDir = String.isBlank(OrderDir) ? 'asc' : OrderDir;
        String query = 'SELECT '+String.join(fieldNameSet, ',')+'  FROM '+ObjectName;
        if(String.isNotBlank(recId)) {
            recId = String.valueOf(recId);
            query += ' WHERE ID >: recId ';
        }
        
        query += ' ORDER BY '+Orderby+' '+OrderDir+' NULLS LAST';
        
        if(LimitSize != null && Integer.valueOf(LimitSize) > 0) {
            LimitSize = Integer.valueOf(LimitSize);
            query += ' Limit '+LimitSize;
        }
        system.debug(LimitSize+'-----'+query+'-----'+recId);
        return Database.query(query);
        //return new List<Account>();
    }

    @AuraEnabled
    public static sObject deleteSObject(sObject sob) {
        delete sob;
        return sob;
    }
    
    @AuraEnabled
    public static void updateRecords(List<sObject> sobList, String updateObjStr, String objectName) {
        //
        System.debug(updateObjStr);
        System.debug(sobList);
        
        schema.SObjectType sobjType = Schema.getGlobalDescribe().get(ObjectName);
        
        Map<String, Schema.sObjectField> sObjectFields = sobjType.getDescribe().fields.getMap();
        List<sObject> updateList = new List<sObject>();
        List<Object> obList = (List<object>) json.deserializeUntyped(updateObjStr);
        for(object ob : obList) {
            Map<String, object> obmap = (Map<String, object>)ob;
            String rowKey = (String)obmap.get('id');
            Integer rowKeyInt = Integer.ValueOf(rowKey.removeStart('row-'));
            
            sobject sObj = sobList[rowKeyInt];
            for(string fieldName : obmap.keySet()) {
                if(fieldName != 'id') {
                    Object value = obmap.get(fieldName);
                    Schema.DisplayType valueType = sObjectFields.get(fieldName).getDescribe().getType();
                    if (value instanceof String && valueType != Schema.DisplayType.String)
                    {
                        String svalue = (String)value;
                        if (valueType == Schema.DisplayType.Date)
                            sObj.put(fieldName, Date.valueOf(svalue));
                        else if(valueType == Schema.DisplayType.DateTime) {
                            try{
                                System.debug( (DateTime)value);
                            }catch(exception ex) {
                                system.debug(ex.getmessage());
                            }
                            String d1 = svalue;
                            list<String> d2 = d1.split('-');
                            list<integer> timeComponent = new list<integer>();
                            timeComponent.add(Integer.valueOf(d2[0]));
                            timeComponent.add(Integer.valueOf(d2[1]));
                            timeComponent.add(Integer.valueOf(d2[2].left(2)));
                            
                            String t = d2[2].substringBetween('T','.');
                            
                            list<String> time1 = t.split(':');
                            timeComponent.add(Integer.valueOf(time1[0]));
                            timeComponent.add(Integer.valueOf(time1[1]));
                            timeComponent.add(Integer.valueOf(time1[2]));
                            
                            Datetime dt = Datetime.newInstance(timeComponent[0],timeComponent[1],timeComponent[2],timeComponent[3],timeComponent[4],timeComponent[5]);
                            sObj.put(fieldName, dt);
                        }
                        //
                        else if (valueType == Schema.DisplayType.Percent || valueType == Schema.DisplayType.Currency)
                            sObj.put(fieldName, svalue == '' ? null : Decimal.valueOf(svalue));
                        else if (valueType == Schema.DisplayType.Double)
                            sObj.put(fieldName, svalue == '' ? null : Double.valueOf(svalue));
                        else if (valueType == Schema.DisplayType.Integer)
                            sObj.put(fieldName, Integer.valueOf(svalue));
                        else if (valueType == Schema.DisplayType.Base64)
                            sObj.put(fieldName, Blob.valueOf(svalue));
                        else
                            sObj.put(fieldName, svalue);
                    }
                    else
                        sObj.put(fieldName, value);
                }
            }
            updateList.add(sObj);
        }
        
        update updateList;
        //return sobList;
    }

    public class DataTableWrapper {
        @AuraEnabled
        public List<LabelDescriptionWrapper> ldwList;
        @AuraEnabled
        public List<sObject> sobList;
        @AuraEnabled
        public List<String> fieldsList;
        @AuraEnabled
        public Integer totalCount;
    }

    public class LabelDescriptionWrapper {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String fieldName;
        @AuraEnabled
        public String type;
        @AuraEnabled
        public boolean sortable;
        @AuraEnabled
        public boolean editable;
        @AuraEnabled
        public TypeAttributes typeAttributes;
        
        public LabelDescriptionWrapper(String labelTemp, String fieldNameTemp, String typeTemp, boolean sortableTemp, boolean editableTemp,TypeAttributes typeAttributesTemp) {
            label 	  = labelTemp;
            fieldName = fieldNameTemp;
            type 	  = typeTemp;
            sortable  = false;//sortableTemp;
            editable = editableTemp;
            typeAttributes = typeAttributesTemp;
        }
    }
    
    public class TypeAttributes  {
        @AuraEnabled
        public List<Actions> rowActions;
        
        public typeAttributes(List<Actions> rowActionsTemp) {
            rowActions 	  = rowActionsTemp;
        }
    }

    public class Actions {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String name;
        
        public Actions(String labelTemp, String nameTemp) {
            label 	  	= labelTemp;
            name 		= nameTemp;
        }
    }
   
}
