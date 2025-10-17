function Home() {
  return <h1>Hello, World</h1>
}

function Home({ post }) {
  return (
    <div>
      <h1>{post.title}</h1>
      <p>{post.body}</p>
    </div>
  )
}

// Esta função roda no servidor a cada requisição
export async function getServerSideProps() {
  try {
    const response = await fetch('https://jsonplaceholder.typicode.com/posts/1')
    const post = await response.json()

    return {
      props: {
        post
      }
    }
  } catch (error) {
    return {
      props: {
        post: null
      }
    }
  }
}

export default Home