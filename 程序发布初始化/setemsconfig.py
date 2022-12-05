import sqlite3

# 建立数据库连接，返回connection对象\
sqlitepath='./ems3/windconfig/db/emsconfig.db'
con=sqlite3.connect(str(sqlitepath))

cur=con.cursor()
temp=6250
OffsetPower=130
ratedw=temp*1000
maxw=(temp*1000)+(OffsetPower*1000)
minw=maxw*0.05
totalnum=18
for i in range(totalnum):
    x=i+1
    turbine="T0"
    if(x<10):
        turbine=turbine+"0"+str(x)
    else:
        turbine=turbine+str(x)
    print(turbine)
    sql="insert into windturbine(id,InOperation,APCMode,RPCMode,APCManSetW,RPCManSetVAr,WMax,WMin,power_curve,VArMax,VArMin,RatedW,TheoVArFactor,DelWMaxForDmdWOverW,WUpDb) values('"+turbine+"',0,0,0,'0','0',"+str(maxw)+","+str(minw)+",'TEST','0','0',"+str(ratedw)+",'0.328','20000000','20000000')"
    print(sql)
    cur.execute(sql)
print ("成功")
con.commit()
con.close()
