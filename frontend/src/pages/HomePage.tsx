import { Container, Title, Text, Code, Paper, Group, Button, List, ThemeIcon } from '@mantine/core';
import { IconCheck, IconExternalLink } from '@tabler/icons-react';
import { Link } from 'react-router-dom';

export default function HomePage() {
  return (
    <Container size="lg" py="xl">
      <Paper p="xl" radius="md" withBorder>
        <Group justify="space-between" mb="xl">
          <div>
            <Title order={1} mb="md">
              Ciao-CORS 代理服务
            </Title>
            <Text size="lg" c="dimmed">
              简单、安全、可配置的CORS代理解决方案
            </Text>
          </div>
          <Button
            component={Link}
            to="/dashboard"
            variant="filled"
            size="lg"
            leftSection={<IconExternalLink size={16} />}
          >
            进入管理后台
          </Button>
        </Group>

        <Paper p="lg" mb="xl" bg="gray.1">
          <Title order={3} mb="md">快速开始</Title>
          <Text mb="md">使用我们的CORS代理服务非常简单，只需在目标URL前加上我们的代理地址：</Text>
          <Code block>
            https://your-domain.com/proxy/https://api.example.com/data
          </Code>
        </Paper>

        <Title order={3} mb="md">主要特性</Title>
        <List
          spacing="sm"
          size="sm"
          center
          icon={
            <ThemeIcon color="teal" size={24} radius="xl">
              <IconCheck size={16} />
            </ThemeIcon>
          }
        >
          <List.Item>
            <Text fw={500}>IP和域名黑白名单</Text>
            <Text size="xs" c="dimmed">精确控制哪些来源可以使用代理服务</Text>
          </List.Item>
          <List.Item>
            <Text fw={500}>请求频率限制</Text>
            <Text size="xs" c="dimmed">防止滥用，保护服务器资源</Text>
          </List.Item>
          <List.Item>
            <Text fw={500}>API密钥管理</Text>
            <Text size="xs" c="dimmed">为不同用户或应用分配独立的访问密钥</Text>
          </List.Item>
          <List.Item>
            <Text fw={500}>详细统计和日志</Text>
            <Text size="xs" c="dimmed">实时监控代理使用情况和性能指标</Text>
          </List.Item>
          <List.Item>
            <Text fw={500}>Docker部署支持</Text>
            <Text size="xs" c="dimmed">一键部署，支持Docker Compose</Text>
          </List.Item>
        </List>

        <Paper p="lg" mt="xl" bg="blue.0">
          <Title order={4} mb="md">配置示例</Title>
          <Text size="sm" mb="sm">在JavaScript中使用：</Text>
          <Code block>
{`fetch('https://your-domain.com/proxy/https://api.example.com/data', {
  method: 'GET',
  headers: {
    'X-API-Key': 'your-api-key'
  }
})
.then(response => response.json())
.then(data => console.log(data));`}
          </Code>
        </Paper>
      </Paper>
    </Container>
  );
}