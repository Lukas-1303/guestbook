const express = require('express');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, ScanCommand, PutCommand, UpdateCommand, DeleteCommand } = require('@aws-sdk/lib-dynamodb');
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(express.json());

// 리전은 환경변수로 받거나 기본값 도쿄(ap-northeast-1) 설정
const client = new DynamoDBClient({ region: process.env.AWS_REGION || 'ap-northeast-1' });
const docClient = DynamoDBDocumentClient.from(client);
const TABLE_NAME = process.env.TABLE_NAME || 'guestbook-memos';

// [Read] 전체 메모 불러오기
app.get('/api/memos', async (req, res) => {
  try {
    const data = await docClient.send(new ScanCommand({ TableName: TABLE_NAME }));
    // 생성 시간순 정렬 (DynamoDB Scan은 순서를 보장하지 않으므로 메모리에서 정렬)
    const sortedItems = data.Items.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    res.json(sortedItems);
  } catch (err) {
    console.error(err);
    res.status(500).send(err);
  }
});

// [Create] 새 메모 작성
app.post('/api/memos', async (req, res) => {
  try {
    const newMemo = {
      id: uuidv4(),
      content: req.body.content,
      created_at: new Date().toISOString()
    };
    await docClient.send(new PutCommand({
      TableName: TABLE_NAME,
      Item: newMemo
    }));
    res.send({ message: '저장 완료' });
  } catch (err) {
    console.error(err);
    res.status(500).send(err);
  }
});

// [Update] 메모 수정하기
app.put('/api/memos/:id', async (req, res) => {
  try {
    await docClient.send(new UpdateCommand({
      TableName: TABLE_NAME,
      Key: { id: req.params.id },
      UpdateExpression: 'set content = :c',
      ExpressionAttributeValues: { ':c': req.body.content }
    }));
    res.send({ message: '수정 완료' });
  } catch (err) {
    console.error(err);
    res.status(500).send(err);
  }
});

// [Delete] 메모 삭제하기
app.delete('/api/memos/:id', async (req, res) => {
  try {
    await docClient.send(new DeleteCommand({
      TableName: TABLE_NAME,
      Key: { id: req.params.id }
    }));
    res.send({ message: '삭제 완료' });
  } catch (err) {
    console.error(err);
    res.status(500).send(err);
  }
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => console.log(`WAS CRUD API is running on port ${PORT}`));
